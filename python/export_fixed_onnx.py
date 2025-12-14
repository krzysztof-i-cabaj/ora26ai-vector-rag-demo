import torch
import torch.nn as nn
from transformers import AutoTokenizer, AutoModel
import onnx
import os

# --- KONFIGURACJA ---
model_id = "sentence-transformers/all-MiniLM-L6-v2"
temp_file = "temp_model.onnx"
final_file = "model_fixed.onnx"
max_seq_length = 128  # 128 tokenów

# --- WRAPPER (3 wejścia, Pooling) ---
class SentenceEmbeddingPipeline(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask, token_type_ids):
        # Model dostanie 3 wejścia. Wewnątrz i tak poradzi sobie z typami.
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask, token_type_ids=token_type_ids)
        token_embeddings = outputs.last_hidden_state
        input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
        sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
        sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
        return sum_embeddings / sum_mask

print(f"--- 1. Pobieranie modelu ---")
tokenizer = AutoTokenizer.from_pretrained(model_id)
base_model = AutoModel.from_pretrained(model_id)
model = SentenceEmbeddingPipeline(base_model)
model.eval()

# --- DANE ---
dummy_input_text = ["This is a test."] * 1
inputs = tokenizer(
    dummy_input_text, 
    padding="max_length", 
    max_length=max_seq_length, 
    truncation=True, 
    return_tensors="pt"
)

# --- WYMUSZENIE INT32 (TO JEST KLUCZ!) ---
print("--- Rzutowanie WSZYSTKICH 3 wejść na INT32... ---")
# To sprawi, że model fizycznie będzie oczekiwał 32 bitów
input_ids_32 = inputs['input_ids'].to(torch.int32)
attention_mask_32 = inputs['attention_mask'].to(torch.int32)
token_type_ids_32 = inputs['token_type_ids'].to(torch.int32)

# --- EKSPORT ---
print(f"--- 2. Eksport do ONNX (3 Inputs, INT32)... ---")
try:
    torch.onnx.export(
        model,
        # Podajemy 3 tensory INT32
        (input_ids_32, attention_mask_32, token_type_ids_32), 
        temp_file,
        opset_version=18,
        input_names=['input_ids', 'attention_mask', 'token_type_ids'],
        output_names=['output_vector'],
        # Static Shapes
    )
except Exception as e:
    print(f"Ostrzeżenie: {e}")

# --- SCALANIE ---
print(f"--- 3. Scalanie pliku... ---")
if not os.path.exists(temp_file):
    print("!!! BŁĄD: Plik nie powstał.")
    exit(1)

onnx_model = onnx.load(temp_file)
onnx.save_model(onnx_model, final_file, save_as_external_data=False)

if os.path.exists(temp_file): os.remove(temp_file)
if os.path.exists(temp_file + ".data"): os.remove(temp_file + ".data")

# --- WERYFIKACJA ---
final_model = onnx.load(final_file)
input_tensor = final_model.graph.input[0]
elem_type = input_tensor.type.tensor_type.elem_type

print("-" * 30)
if elem_type == 6:
    print("SUKCES: Plik jest INT32 (Typ 6).")
else:
    print(f"BŁĄD: Plik jest typem {elem_type}.")
print("-" * 30)
