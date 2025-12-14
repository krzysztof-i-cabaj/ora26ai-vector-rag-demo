"""
Konwersja modelu Sentence Transformer do ONNX - kompatybilny z Oracle 23ai
Używa starego eksportera torch.onnx dla lepszej kompatybilności
"""
import torch
from transformers import AutoTokenizer, AutoModel
import onnx
import warnings
warnings.filterwarnings('ignore')

print("--- 1. Pobieranie modelu ---")
model_name = "sentence-transformers/all-MiniLM-L6-v2"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModel.from_pretrained(model_name)
model.eval()

class SentenceEmbedding(torch.nn.Module):
    def __init__(self, transformer_model):
        super().__init__()
        self.model = transformer_model
    
    def forward(self, input_ids, attention_mask, token_type_ids):
        with torch.no_grad():
            outputs = self.model(
                input_ids=input_ids,
                attention_mask=attention_mask,
                token_type_ids=token_type_ids
            )
            # Mean pooling
            token_embeddings = outputs.last_hidden_state
            input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
            sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
            sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
            embeddings = sum_embeddings / sum_mask
            # Normalizacja L2
            embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
            return embeddings

pipeline = SentenceEmbedding(model)
pipeline.eval()

print("--- 2. Eksport do ONNX (legacy exporter, INT64) ---")
MAX_SEQ_LENGTH = 128

dummy_text = "Oracle AI Vector Search"
inputs = tokenizer(
    dummy_text,
    padding='max_length',
    truncation=True,
    max_length=MAX_SEQ_LENGTH,
    return_tensors="pt"
)

# INT64 dla indeksów
input_ids = inputs['input_ids'].to(torch.long)
attention_mask = inputs['attention_mask'].to(torch.long)
token_type_ids = inputs['token_type_ids'].to(torch.long)

print(f"Typy wejść: {input_ids.dtype}, {attention_mask.dtype}, {token_type_ids.dtype}")

# Użyj STAREGO eksportera (bardziej kompatybilny)
torch.onnx.export(
    pipeline,
    (input_ids, attention_mask, token_type_ids),
    "model_legacy.onnx",
    export_params=True,
    opset_version=14,  # Niższa wersja = lepsza kompatybilność
    do_constant_folding=True,
    input_names=['input_ids', 'attention_mask', 'token_type_ids'],
    output_names=['output_vector'],
    dynamic_axes={
        'input_ids': {0: 'batch_size'},
        'attention_mask': {0: 'batch_size'},
        'token_type_ids': {0: 'batch_size'},
        'output_vector': {0: 'batch_size'}
    }
)

print("--- 3. Scalanie ---")
model_onnx = onnx.load("model_legacy.onnx", load_external_data=True)
onnx.save(model_onnx, "model_legacy_merged.onnx")

print("--- 4. Weryfikacja ---")
model_check = onnx.load("model_legacy_merged.onnx")

type_names = {1: "FLOAT32", 6: "INT32", 7: "INT64"}
print("\nWejścia:")
for inp in model_check.graph.input:
    elem_type = inp.type.tensor_type.elem_type
    shape = []
    for dim in inp.type.tensor_type.shape.dim:
        if dim.dim_param:
            shape.append(dim.dim_param)
        else:
            shape.append(str(dim.dim_value))
    print(f"  {inp.name}: {type_names.get(elem_type, elem_type)} [{', '.join(shape)}]")

print("\nWyjścia:")
for out in model_check.graph.output:
    elem_type = out.type.tensor_type.elem_type
    print(f"  {out.name}: {type_names.get(elem_type, elem_type)}")

print(f"\n✓ GOTOWE: model_legacy_merged.onnx ({model_check.ByteSize()/1024/1024:.1f} MB)")
print("✓ Używa legacy exporter (opset 14)")
print("✓ Tokeny: INT64")
print("\nSkopiuj do Oracle:")
print("cp model_legacy_merged.onnx /opt/oracle/oradata/models/")
