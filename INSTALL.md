\# 🛠️ Installation \& Setup Guide: Galactic Support RAG



This document provides step-by-step instructions to deploy the \*\*Galactic Support Desk\*\* demo on an Oracle 23ai Database.



It covers environment setup, model acquisition (including the educational "Python Engineering" path), and data seeding.



---



\## 📋 Prerequisites



Before you begin, ensure you have the following:



1\.  \*\*Oracle Database 23ai\*\*

&nbsp;   \* Free Developer Release or Enterprise Edition.

&nbsp;   \* Running on Linux (OL8/OL9) or via Docker container.

2\.  \*\*Operating System Tools\*\*

&nbsp;   \* `git`, `wget`, `unzip`.

3\.  \*\*Python 3.10+\*\* (Optional - for local visualization)

&nbsp;   \* Libraries: `oracledb`, `numpy`, `matplotlib`, `plotly`, `pandas`.



---



\## 🚀 Step 1: Clone the Repository



Clone the project code to your local machine or database server:



```bash

git clone \[https://github.com/krzysztof-i-cabaj/ora26ai-vector-rag-demo.git](https://github.com/krzysztof-i-cabaj/ora26ai-vector-rag-demo.git)

cd ora26ai-vector-rag-demo



---



\## ⚙️ Step 2: Database Preparation



We need to create a dedicated user (`vec\_admin`) and a directory object pointing to where the ONNX model will reside.



1\.  \*\*Log in to your Database Host\*\* and create the physical directory for models:

&nbsp;   ```bash

&nbsp;   # Example for standard installation (adjust path as needed)

&nbsp;   mkdir -p /opt/oracle/oradata/models

&nbsp;   chmod 755 /opt/oracle/oradata/models

&nbsp;   ```



2\.  \*\*Connect to the Database\*\* as `SYS` (using SQLcl or SQLPlus) and run the setup script:

&nbsp;   ```sql

&nbsp;   -- Login as SYS

&nbsp;   -- (Replace connection string with your details)

&nbsp;   sql sys/password@localhost:1521/freepdb1 as sysdba



&nbsp;   -- Run the setup script

&nbsp;   @sql/01\_sys\_setup.sql

&nbsp;   ```



> \*\*⚠️ Important:\*\* Open `sql/01\_sys\_setup.sql` before running it and ensure the `CREATE OR REPLACE DIRECTORY VEC\_MODELS` path matches the folder you created in point 1.





---



\## 🧠 Step 3: Model Strategy (Choose One)



To perform Vector Search, we need to load an embedding model into the database kernel. You have two options.



\### 🟢 Option A: The "Production" Path (Recommended)

Use the \*\*Augmented L12 Model\*\* officially provided by Oracle via OCI. This model is pre-optimized for OML and avoids `ORA-54448` memory allocation errors caused by dynamic axes.



1\.  Navigate to your model directory:

&nbsp;   ```bash

&nbsp;   cd /opt/oracle/oradata/models

&nbsp;   ```

2\.  Download and unzip the model:

&nbsp;   ```bash

&nbsp;   wget \[https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/VBRD9P8ZFWkKvnfhrWxkpPe8K03-JIoM5h\_8EJyJcpE80c108fuUjg7R5L5O7mMZ/n/adwc4pm/b/OML-Resources/o/all\_MiniLM\_L12\_v2\_augmented.zip](https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/VBRD9P8ZFWkKvnfhrWxkpPe8K03-JIoM5h\_8EJyJcpE80c108fuUjg7R5L5O7mMZ/n/adwc4pm/b/OML-Resources/o/all\_MiniLM\_L12\_v2\_augmented.zip)

&nbsp;   

&nbsp;   unzip all\_MiniLM\_L12\_v2\_augmented.zip

&nbsp;   ```

3\.  \*\*Result:\*\* You should see `all\_MiniLM\_L12\_v2.onnx` in the directory.



\### 🧪 Option B: The "Research" Path (Educational)

If you want to understand \*how\* to manually fix standard ONNX models (fixing Dynamic Axes using PyTorch), follow this path.



1\.  Install the deep learning requirements locally:

&nbsp;   ```bash

&nbsp;   pip install -r requirements-dev.txt

&nbsp;   ```

&nbsp;   \*(Includes `torch`, `transformers`, `onnx`, `onnxruntime`)\*

2\.  Run the fix script:

&nbsp;   ```bash

&nbsp;   cd python

&nbsp;   python fix\_onnx\_model.py

&nbsp;   ```

&nbsp;   \*This script downloads `all-MiniLM-L6-v2` from HuggingFace, freezes the input dimensions to \[1, 128], and saves a new `.onnx` file.\*

3\.  Move the generated file to your database model directory `/opt/oracle/oradata/models`.



---



\## 📥 Step 4: Load Model into Database



Now we load the ONNX file into the database memory (In-Database Embeddings).



1\.  Connect as the \*\*`vec\_admin`\*\* user created in Step 2.

2\.  Run the loading script:



```sql

-- Connect as vec\_admin

sql vec\_admin/Welcome12345!@localhost:1521/freepdb1



-- Load the model

@sql/02\_load\_onnx.sql



---



\## 💾 Step 5: Data Seeding \& Vectorization



Now we generate the "Galactic Tickets". The script will insert text data and automatically calculate embeddings using the loaded model.

Phase 1: Pilot Data (50 Records)



Run the base generation script to create the table and insert standard issues:

```sql

@sql/03\_data\_gen\_v2.sql



Phase 2: Stress Test (Enrichment)



To test the robustness of the clustering, inject 72 additional "edge case" records:

```sql

@sql/03\_data\_enrich.sql



This adds ambiguous descriptions to test if the semantic search can distinguish between similar contexts (e.g., "Firewall breach" vs "Thermal shield breach").





---



\## 📊 Step 6: Visualization (Optional)



To generate the cluster visualization (`galactic\_clusters.png`) locally:



1\.  Install visualization requirements:

&nbsp;   ```bash

&nbsp;   pip install -r requirements.txt

&nbsp;   ```

2\.  Run the Python visualizer:

&nbsp;   ```bash

&nbsp;   cd python

&nbsp;   # Ensure database credentials in the script match your setup

&nbsp;   python 05\_visualize\_clusters.py

&nbsp;   ```



---



\## ❓ Troubleshooting



\*\*Error: `ORA-54448: input tensor ... exceeds maximum size`\*\*

\* \*\*Cause:\*\* The ONNX model has dynamic axes (variable input length), which the Oracle Kernel allocator rejects.

\* \*\*Fix:\*\* Ensure you are using the \*\*Augmented L12\*\* model (Option A) or that you successfully ran the `fix\_onnx\_model.py` script (Option B) to enforce static shapes.



\*\*Error: `ORA-20000: Model not found`\*\*

\* \*\*Cause:\*\* The filename in `DBMS\_VECTOR.LOAD\_ONNX\_MODEL` does not match the file on the disk.

\* \*\*Fix:\*\* Check `ls -lh /opt/oracle/oradata/models` and update `02\_load\_onnx.sql` to match the exact filename.





