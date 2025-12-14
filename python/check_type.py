import onnx

# Wczytujemy plik
model_path = "model_fixed.onnx"
model = onnx.load(model_path)

# Sprawdzamy typ pierwszego wejścia (input_ids)
input_tensor = model.graph.input[0]
elem_type = input_tensor.type.tensor_type.elem_type

print("-" * 30)
if elem_type == 7:
    print(f"JESTEŚ INT64 (Typ: {elem_type})")
    print("REKOMENDACJA: Użyj SQL dla INT64")
elif elem_type == 6:
    print(f"JESTEŚ INT32 (Typ: {elem_type})")
    print("REKOMENDACJA: Użyj SQL dla INT32")
else:
    print(f"JESTEŚ INNYM TYPEM (Typ: {elem_type})")
print("-" * 30)
