/* * ======================================================================================
 * SCRIPT: 02_load_onnx_final.sql
 * AUTHOR: KCB Kris
 * PL: Import modelu ONNX - wersja MINIMALNA (auto-wykrywanie metadanych)
 * EN: Importing ONNX model - MINIMAL version (metadata auto-detection)
 * ======================================================================================
 */

SET SERVEROUTPUT ON

DECLARE
    v_model_name VARCHAR2(100) := 'DOC_MODEL';
BEGIN
    -- 1. Usuwanie starego modelu
    DBMS_OUTPUT.PUT_LINE('[INFO] Droping old/existing model ...');
    BEGIN 
	DBMS_VECTOR.DROP_ONNX_MODEL(v_model_name, force => TRUE); 
	DBMS_OUTPUT.PUT_LINE('    ✓ Dropped');
    EXCEPTION WHEN OTHERS THEN 
	DBMS_OUTPUT.PUT_LINE('    No old model (OK)'); 
    END;

    DBMS_OUTPUT.PUT_LINE('[INFO] Loading ONNX model all_MiniLM_L12_v2.onnx...');

    -- 2. LOAD NEW MODEL (Simplified Block)
    -- PL: W najnowszych buildach 23ai, parametr 'metadata' jest opcjonalny.
    --     Baza sama odczytuje wejścia/wyjścia z pliku binarnego.
    -- EN: In latest 23ai builds, 'metadata' parameter is optional.
    --     DB reads inputs/outputs directly from the binary file.
    BEGIN
    DBMS_VECTOR.LOAD_ONNX_MODEL(
        directory  => 'ONNX_IMPORT_DIR',
        file_name  => 'all_MiniLM_L12_v2.onnx',
        model_name => v_model_name,
        metadata   => JSON('{"function":"embedding", "embeddingOutput":"embedding", "input":{"input":["DATA"]}}')
    );
    DBMS_OUTPUT.PUT_LINE('[SUCCESS] Model loaded...');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[3] ✗ ERROR model loading:');
            DBMS_OUTPUT.PUT_LINE('    ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('    Backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            RAISE;
    END;

    DBMS_OUTPUT.PUT_LINE('[INFO] Checking in user_mining_models...');
    FOR r IN (SELECT model_name, mining_function, algorithm
              FROM user_mining_models
              WHERE model_name = 'DOC_MODEL') LOOP
        DBMS_OUTPUT.PUT_LINE('    ✓ Model: ' || r.model_name || ' (' || r.mining_function || ')');
    END LOOP;
END;
/
