# convert_fixed_sequence.py
import torch
from transformers import AutoTokenizer, AutoModel
import onnx
from onnx import TensorProto

print("--- 1. Pobieranie modelu ---")
model_name = "sentence-transformers/all-MiniLM-L6-v2"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModel.from_pretrained(model_name)
model.eval()

class SentenceEmbeddingPipeline(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    
    def forward(self, input_ids, attention_mask, token_type_ids):
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

pipeline = SentenceEmbeddingPipeline(model)

print("--- 2. Eksport do ONNX (STAŁA długość sekwencji)... ---")
MAX_SEQ_LENGTH = 128  # Stała długość

dummy_text = "Oracle AI Vector Search"
inputs = tokenizer(
    dummy_text,
    padding='max_length',
    truncation=True,
    max_length=MAX_SEQ_LENGTH,
    return_tensors="pt"
)

# INT64 dla Oracle
input_ids = inputs['input_ids'].to(torch.int64)
attention_mask = inputs['attention_mask'].to(torch.int64)
token_type_ids = inputs['token_type_ids'].to(torch.int64)

torch.onnx.export(
    pipeline,
    (input_ids, attention_mask, token_type_ids),
    "model_oracle.onnx",
    input_names=['input_ids', 'attention_mask', 'token_type_ids'],
    output_names=['output_vector'],
    dynamic_axes={
        # TYLKO batch_size dynamiczny, sequence jest stały!
        'input_ids': {0: 'batch_size'},
        'attention_mask': {0: 'batch_size'},
        'token_type_ids': {0: 'batch_size'},
        'output_vector': {0: 'batch_size'}
    },
    opset_version=17
)

print("--- 3. Scalanie do pojedynczego pliku... ---")
model_onnx = onnx.load("model_oracle.onnx", load_external_data=True)
onnx.save(model_onnx, "model_oracle_merged.onnx")

print("--- 4. Weryfikacja... ---")
model_check = onnx.load("model_oracle_merged.onnx")

for inp in model_check.graph.input:
    print(f"\nInput: {inp.name}")
    print(f"  Type: {inp.type.tensor_type.elem_type} (7=INT64)")
    print(f"  Shape: ", end="")
    for dim in inp.type.tensor_type.shape.dim:
        if dim.dim_param:
            print(f"{dim.dim_param} (dynamic)", end=" ")
        else:
            print(f"{dim.dim_value} (fixed)", end=" ")
    print()

print("\n✓ GOTOWE: model_oracle_merged.onnx")
print(f"✓ Rozmiar: {model_check.ByteSize()/1024/1024:.1f} MB")
print(f"✓ Długość sekwencji: {MAX_SEQ_LENGTH} (stała)")
print(f"✓ Batch size: dynamiczny")
