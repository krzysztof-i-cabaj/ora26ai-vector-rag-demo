/* * ======================================================================================
 * SCRIPT: 03_data_enrich.sql
 * AUTHOR: GitHub Copilot
 * PL: Wzbogacenie danych ENG/SEC i wektoryzacja tylko nowych wierszy
 * EN: Enrich ENG/SEC data and vectorize only new rows
 * ======================================================================================
 */

SET SERVEROUTPUT ON
SET TIMING ON

DECLARE
    TYPE t_array IS TABLE OF VARCHAR2(4000);

    v_eng_phrases t_array := t_array(
        'Quantum shield emitter desynchronization during warp entry.',
        'Plasma conduit backflow detected in starboard manifold.',
        'Superluminal gyro misalignment causes drift in navigation.',
        'Fusion core injector latency exceeds safety threshold.',
        'Cryo-pump cavitation in coolant loop B.',
        'Subspace antenna phase noise impacting telemetry.',
        'Nanoforge print head clogged with composite dust.',
        'Magnetoplasma thruster oscillation observed under load.',
        'Optical nav lidar returns saturated frames due to sun glint.',
        'Power bus ripple exceeds avionics tolerance; DC-DC regulators fold back.',
        'Deterministic jitter on real-time CAN-FD backbone after firmware rollback.',
        'FPGA bitstream CRC mismatch during hot reload of flight computer.',
        'Cryogenic loop delta-T runaway; PID controller stuck in integral windup.',
        'Attitude control Kalman filter diverging because IMU bias drift went uncorrected.',
        'Refueling umbilical sensor reports NaN; PLC interlock fails closed.',
        'Edge microservice running incompatible ABI after patch; gRPC handshake fails.',
        'Telemetry packet loss traced to DDS QoS misconfiguration under congestion.',
        'Overloaded object storage returns 503; pipeline backpressure propagates upstream.'
    );

    v_sec_phrases t_array := t_array(
        'Zero-trust policy violation from external enclave.',
        'Privileged credential escalation attempt flagged.',
        'Tamper-evident seal broken on secure vault.',
        'Unauthorized policy override detected in IAM controller.',
        'Audit trail gap in identity federation handshake.',
        'Anomalous MFA push fatigue signs reported.',
        'Data exfiltration pattern matching high-confidence signature.',
        'Quarantine event: rogue synthetic identity blocked.',
        'Malicious dependency injection in CI pipeline via typosquat package.',
        'TLS pinning bypass attempt using rogue root cert installed on kiosk fleet.',
        'SIEM flagged C2 beacon cadence over DNS tunneling channel.',
        'Ransomware lateral movement via legacy SMBv1 share; EDR blocked encryption.',
        'Container escape attempt abusing /proc namespace and unpatched kernel CVE.',
        'Shadow API endpoint exposed without WAF coverage; bearer tokens leaking.',
        'DLP policy triggered on outbound S3 sync containing PII inventory.',
        'HSM rate limiting tripped after repeated failed signing operations.',
        'Insider staging data to personal cloud by bypassing corporate proxy.',
        'IoT gateway firmware signed with weak RSA-1024 key; rotation overdue.'
    );
BEGIN
    DBMS_OUTPUT.PUT_LINE('[INFO] Inserting enriched ENGINEERING tickets...');
    FOR i IN 1..v_eng_phrases.COUNT LOOP
        INSERT INTO galactic_tickets (severity, department, description)
        VALUES ('HIGH', 'ENGINEERING', v_eng_phrases(i) || ' [EnrichID: ' || DBMS_RANDOM.STRING('X', 5) || ']');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('[INFO] Inserting enriched SECURITY tickets...');
    FOR i IN 1..v_sec_phrases.COUNT LOOP
        INSERT INTO galactic_tickets (severity, department, description)
        VALUES ('CRITICAL', 'SECURITY', v_sec_phrases(i) || ' [EnrichID: ' || DBMS_RANDOM.STRING('X', 5) || ']');
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[SUCCESS] Inserts committed.');

    DBMS_OUTPUT.PUT_LINE('[INFO] Vectorizing only NEW rows (embedding IS NULL)...');
    UPDATE galactic_tickets
    SET embedding = VECTOR_EMBEDDING(DOC_MODEL USING description AS DATA)
    WHERE embedding IS NULL;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[SUCCESS] New rows vectorized.');

    DBMS_OUTPUT.PUT_LINE('[INFO] Row counts (post-enrichment):');
    FOR r IN (
        SELECT department, COUNT(*) AS cnt
        FROM galactic_tickets
        GROUP BY department
        ORDER BY department
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('    ' || r.department || ': ' || r.cnt);
    END LOOP;
END;
/

-- Quick verification of total vectors
SELECT COUNT(*) AS total_vectorized FROM galactic_tickets WHERE embedding IS NOT NULL;
