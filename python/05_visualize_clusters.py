# ======================================================================================
# SCRIPT: 05_visualize_clusters.py
# AUTHOR: KCB Kris
# PL: Pobiera wektory z Oracle DB, redukuje wymiary (PCA) i rysuje mapę tematów.
# EN: Fetches vectors from Oracle DB, reduces dimensions (PCA), and plots topic map.
# pip install oracledb matplotlib scikit-learn numpy
# ======================================================================================

import oracledb
import numpy as np
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA

# --- CONFIGURATION ---
# Zmień dane logowania na swoje / Change credentials to yours
USER = "vec_admin"
PASS = "Oracle_2024!"
DSN  = "localhost:1521/freepdb1" 

print("[INFO] Connecting to Oracle Database...")

try:
    # PL: Tryb 'thin' w najnowszym oracledb obsługuje typy VECTOR natywnie
    # EN: 'thin' mode in latest oracledb supports VECTOR types natively
    connection = oracledb.connect(user=USER, password=PASS, dsn=DSN)
    cursor = connection.cursor()

    # PL: Pobieramy departament (jako etykietę) i wektor
    # EN: Fetching department (as label) and vector
    sql = """
        SELECT department, embedding 
        FROM galactic_tickets 
        WHERE embedding IS NOT NULL
    """
    
    cursor.execute(sql)
    rows = cursor.fetchall()
    
    if not rows:
        print("[ERROR] No data found. Run script 03 first!")
        exit()

    print(f"[INFO] Fetched {len(rows)} rows. Processing vectors...")

    # PL: Przygotowanie danych dla Scikit-Learn
    # EN: Preparing data for Scikit-Learn
    labels = []
    vectors = []

    for row in rows:
        dept = row[0]
        # Oracle driver returns vector as array.array usually, convert to list/numpy
        vec_data = np.array(row[1], dtype='float32')
        
        labels.append(dept)
        vectors.append(vec_data)

    X = np.array(vectors)

    # --- DIMENSIONALITY REDUCTION (PCA) ---
    # PL: Redukcja z 384 wymiarów do 2, aby narysować na ekranie
    # EN: Reducing from 384 dimensions to 2 to plot on screen
    print(f"[INFO] Reducing dimensions from {X.shape[1]} to 2 using PCA...")
    pca = PCA(n_components=2)
    X_reduced = pca.fit_transform(X)

    # --- PLOTTING ---
    print("[INFO] Generating Plot...")
    plt.figure(figsize=(12, 8))
    
    # Mapowanie kolorów dla departamentów / Color mapping
    unique_labels = list(set(labels))
    colors = plt.cm.rainbow(np.linspace(0, 1, len(unique_labels)))
    
    for i, label in enumerate(unique_labels):
        # Wybierz punkty należące do danej kategorii
        idxs = [j for j, l in enumerate(labels) if l == label]
        plt.scatter(
            X_reduced[idxs, 0], 
            X_reduced[idxs, 1], 
            color=colors[i], 
            label=label, 
            alpha=0.7, 
            s=100,
            edgecolors='k' # czarna obwódka punktu
        )

    plt.title('Semantic Map of Galactic Support Tickets (Oracle Vector Search)', fontsize=15)
    plt.xlabel('Semantic Dimension 1 (PCA)', fontsize=12)
    plt.ylabel('Semantic Dimension 2 (PCA)', fontsize=12)
    plt.legend(title="Department")
    plt.grid(True, linestyle='--', alpha=0.5)
    
    output_file = "galactic_clusters.png"
    plt.savefig(output_file)
    print(f"[SUCCESS] Plot saved as: {output_file}")
    
    # Opcjonalnie pokaż (jeśli masz UI):
    # plt.show()

except oracledb.Error as e:
    print(f"[ERROR] Oracle Error: {e}")
finally:
    if 'connection' in locals():
        connection.close()