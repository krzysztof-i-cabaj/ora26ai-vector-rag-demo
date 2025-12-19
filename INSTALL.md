# 🛠️ Installation & Setup Guide: Galactic Support RAG



This document provides step-by-step instructions to deploy the **Galactic Support Desk** demo on an Oracle 23ai Database.



It covers environment setup, model acquisition (including the educational "Python Engineering" path), and data seeding.



---



## 📋 Prerequisites



Before you begin, ensure you have the following:



1.  **Oracle Database 23ai**

&nbsp;   * Free Developer Release or Enterprise Edition.

&nbsp;   * Running on Linux (OL8/OL9) or via Docker container.

2.  **Operating System Tools**

&nbsp;   * `git`, `wget`, `unzip`.

3.  **Python 3.10+** (Optional - for local visualization)

&nbsp;   * Libraries: `oracledb`, `numpy`, `matplotlib`, `plotly`, `pandas`.



---



## 🚀 Step 1: Clone the Repository



Clone the project code to your local machine or database server:



```bash

git clone [https://github.com/krzysztof-i-cabaj/ora26ai-vector-rag-demo.git](https://github.com/krzysztof-i-cabaj/ora26ai-vector-rag-demo.git)

cd ora26ai-vector-rag-demo
```


---



## ⚙️ Step 2: Database Preparation



We need to create a dedicated user (`vec_admin`) and a directory object pointing to where the ONNX model will reside.



1.  **Log in to your Database Host** and create the physical directory for models:

 ```bash

# Example for standard installation (adjust path as needed)

mkdir -p /opt/oracle/oradata/models

chmod 755 /opt/oracle/oradata/models

```



2.  **Connect to the Database** as `SYS` (using SQLcl or SQLPlus) and run the setup script:

 ```sql

-- Login as SYS

-- (Replace connection string with your details)

sql sys/password@localhost:1521/freepdb1 as sysdba



-- Run the setup script

@01_sys_setup.sql

```



> **⚠️ Important:** Open `01_sys_setup.sql` before running it and ensure the `CREATE OR REPLACE DIRECTORY VEC_MODELS` path matches the folder you created in point 1.





---



## 🧠 Step 3: Model Strategy (Choose One)



To perform Vector Search, we need to load an embedding model into the database kernel. You have two options.



### 🟢 Option A: The "Production" Path (Recommended)

Use the **Augmented L12 Model*\ officially provided by Oracle via OCI. This model is pre-optimized for OML and avoids `ORA-54448` memory allocation errors caused by dynamic axes.



1.  Navigate to your model directory:

```bash

cd /opt/oracle/oradata/models

 ```

2.  Download and unzip the model:

```bash

wget [https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/VBRD9P8ZFWkKvnfhrWxkpPe8K03-JIoM5h_8EJyJcpE80c108fuUjg7R5L5O7mMZ/n/adwc4pm/b/OML-Resources/o/all_MiniLM_L12_v2_augmented.zip](https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/VBRD9P8ZFWkKvnfhrWxkpPe8K03-JIoM5h_8EJyJcpE80c108fuUjg7R5L5O7mMZ/n/adwc4pm/b/OML-Resources/o/all_MiniLM_L12_v2_augmented.zip)

 

unzip all_MiniLM_L12_v2_augmented.zip

```

3.  **Result:** You should see `all_MiniLM_L12_v2.onnx` in the directory.



### 🧪 Option B: The "Research" Path (Educational)

If you want to understand *how* to manually fix standard ONNX models (fixing Dynamic Axes using PyTorch), follow this path.



1.  Install the deep learning requirements locally:

```bash

pip install -r requirements-dev.txt

 ```

*(Includes `torch`, `transformers`, `onnx`, `onnxruntime`)*

2.  Run the fix script:

```bash

cd python

python fix_onnx_model.py

```

*This script downloads `all-MiniLM-L6-v2` from HuggingFace, freezes the input dimensions to [1, 128], and saves a new `.onnx` file.*

3.  Move the generated file to your database model directory `/opt/oracle/oradata/models`.



---



## 📥 Step 4: Load Model into Database



Now we load the ONNX file into the database memory (In-Database Embeddings).



1.  Connect as the **`vec_admin`** user created in Step 2.

2.  Run the loading script:



```sql

-- Connect as vec_admin

sql vec_admin/Welcome12345!@localhost:1521/freepdb1

-- Load the model

@02_load_onnx.sql
```


---



## 💾 Step 5: Data Seeding \& Vectorization



Now we generate the "Galactic Tickets". The script will insert text data and automatically calculate embeddings using the loaded model.

Phase 1: Pilot Data (50 Records)



Run the base generation script to create the table and insert standard issues:

```sql

@03_data_gen_v2.sql

```

Phase 2: Stress Test (Enrichment)



To test the robustness of the clustering, inject 72 additional "edge case" records:


```sql

@03_data_enrich.sql

```

This adds ambiguous descriptions to test if the semantic search can distinguish between similar contexts (e.g., "Firewall breach" vs "Thermal shield breach").





---



## 📊 Step 6: Visualization (Optional)



To generate the cluster visualization (`galactic_clusters.png`) locally:



1.  Install visualization requirements:

```bash

pip install -r requirements.txt

 ```

2.   Run the Python visualizer:

```bash

cd python

# Ensure database credentials in the script match your setup

python 05_visualize_clusters.py

```



---



## ❓ Troubleshooting



**Error: `ORA-54448: input tensor ... exceeds maximum size`**

* **Cause:** The ONNX model has dynamic axes (variable input length), which the Oracle Kernel allocator rejects.

* **Fix:** Ensure you are using the **Augmented L12** model (Option A) or that you successfully ran the `fix_onnx\model.py` script (Option B) to enforce static shapes.



**Error: `ORA-20000: Model not found`**

* **Cause:** The filename in `DBMS_VECTOR.LOAD_ONNX\_MODEL` does not match the file on the disk.

* **Fix:** Check `ls -lh /opt/oracle/oradata/models` and update `02_load_onnx.sql` to match the exact filename.





