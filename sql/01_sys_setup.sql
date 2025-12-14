/* * ======================================================================================
 * SCRIPT: 01_sys_setup.sql
 * AUTHOR: KCB Kris
 * PL: Konfiguracja użytkownika i katalogu dla modelu ONNX
 * EN: User configuration and directory setup for ONNX model
 * ======================================================================================
 */

-- PL: Tworzenie dedykowanego użytkownika dla naszego projektu Vector RAG
-- EN: Creating a dedicated user for our Vector RAG project
CREATE USER vec_admin IDENTIFIED BY "Oracle_2024!" 
DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;

GRANT DB_DEVELOPER_ROLE TO vec_admin;
GRANT CREATE MINING MODEL TO vec_admin; -- PL: Kluczowe uprawnienie do ładowania modeli / EN: Key privilege for loading models

-- PL: Wskazanie katalogu systemu plików, gdzie leży plik .onnx
-- EN: Pointing to the file system directory where the .onnx file resides
CREATE OR REPLACE DIRECTORY ONNX_IMPORT_DIR AS '/opt/oracle/oradata/models';

GRANT READ, WRITE ON DIRECTORY ONNX_IMPORT_DIR TO vec_admin;

PROMPT [INFO] System setup complete. User VEC_ADMIN created.