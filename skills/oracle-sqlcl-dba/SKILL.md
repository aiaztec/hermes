---
name: oracle
description: Oracle Database workflow trigger. ALWAYS load the hub-installed db skill first before doing anything else. Never improvise Oracle/SQL/PLSQL/SQLcl/MCP/database work from generic knowledge when this skill is active.
---

# Oracle Workflow Skill

## Trigger Rule
**At the start of ANY Oracle-related task**, immediately do:
```bash
skill_view(name='db')
```

This is not optional. It is the first action, before any web search, terminal command, or improvisation.

## Why
- The `db` skill contains: sqlcl-basics, sqlcl-mcp-server, PL/SQL, performance, security, migrations, agentsafe DB patterns, and 70+ sub-skills.
- Improvising from web search or generic knowledge produces incorrect syntax, missed security rules, and duplicate work.
- This skill exists specifically so the failure to load `db` cannot happen by accident.

## Pitfall
If you catch yourself writing Oracle advice without having read `db` this session, STOP. Reload `db`, then continue.

---
name: oracle-sqlcl-dba
description: Správa, audit a optimalizácia Oracle databáz pomocou SQLcl 25.4. Pokrýva pripojenie, administráciu, monitoring výkonu, audit, zálohovanie (Data Pump) a CI/CD.
---

# Oracle SQLcl 25.4 - DBA Skill

Oracle SQLcl (SQL Developer Command Line) je Java-based CLI nástroj pre Oracle Database. Verzia 25.4 prináša vylepšenia pre AI Database, JavaScript podporu a MCP server.

## Inštalácia a požiadavky

- **Java**: Oracle Java 11, 17 alebo 21
- **Stiahnutie**: z Oracle Technology Network
- **Spustenie**: `sql /nolog` alebo `sql user/password@host:port/service`

## Pripojenie k databáze

### Verzia SQLcl
- **Dokumentácia v skillu:** 25.4 (študovaná)
- **Používateľova verzia:** 26.1.0.0 (novšia, plne kompatibilná)
## Pripojenie k databáze

### Ukladanie pripojení (odporúčané)
SQLcl umožňuje uložiť pripojenia vrátane hesiel priamo v jeho konfigurácii. **Poznámka: Pripojenie sa uloží LEN pri úspešnom pripojení (neúspešné pokusy sa neukladajú).** 

**Používateľova syntax pre ukladanie:**
```sql
conn -save <NAZOV> -savepwd <USER>/<HESLO>@<HOST>:<PORT>/<SERVICE_NAME>
```

Príklad (skutočné použitie zo session):
```sql
conn -save CLOUD19D -savepwd aidba/dfjS23rRTwaTRCw342@192.168.221.195:1521/CLOUD19D
```

**Efektívne pripojenie (používateľova preferencia):**
```bash
# NAMIESTO: sql /nolog <<EOF ... EOF
# POUŽI: Jednoduché pripojenie cez -name
sql -name CLOUD19D
```

### Správa uložených pripojení
Pre SQLcl 26.1+ použi `connmgr` nástroj:
```sql
-- Zoznam všetkých uložených pripojení (flat výpis)
connmgr list -flat

-- Podrobnosti o konkrétnom pripojení
connmgr show CLOUD19D

-- Odstránenie uloženého pripojenia
connmgr delete -conn CLOUD19D

-- Test uloženého pripojenia
connmgr test CLOUD19D
```

### Ďalšie spôsoby pripojenia
```bash
# Štandardné pripojenie
sql system/password@localhost:1521/ORCLPDB1

# Pripojenie bez prihlásenia (potom CONNECT)
sql /nolog
SQL> CONNECT system/password@localhost:1521/ORCLPDB1

# Pripojenie cez TNS alias
sql system/password@TNSALIAS

# Pripojenie s premennými prostredia
export TNS_ADMIN=/path/to/tnsnames.ora
sql system/password@ORCL
```

### Efektívna syntax pripojenia (odporúčané)
**Používateľova korekcia:** Namiesto zdĺhavého `sql /nolog <<EOF...EOF` používaj `sql -name`:
```bash
# Efektívne pripojenie (odporúčané)
sql -name CLOUD19B <<EOF
SELECT * FROM v\$database;
exit
EOF

# Namiesto:
# sql /nolog <<EOF
# conn CLOUD19B
# ...
# EOF
```

## Základné administratívne príkazy

### Informácie o databáze
```sql
-- Verzia databázy
SELECT * FROM v$version;

-- Meno databázy a inštancie
SELECT name, db_unique_name, instance_name FROM v$database, v$instance;

-- Uptime databázy
SELECT instance_name, startup_time, 
       ROUND(SYSDATE - startup_time) AS days_up
FROM v$instance;

-- Architektúra (CDB/PDB)
SHOW CON_NAME
SELECT name, open_mode FROM v$pdbs;
```

### Správa tablespaceov a úložiska
```sql
-- Voľné miesto v tablespaceoch (OPRAVENÉ - pôvodne chyba ORA-00918)
SELECT 
    df.tablespace_name, 
    ROUND(SUM(df.bytes)/1024/1024) AS total_mb,
    ROUND(SUM(df.bytes - NVL(free.bytes,0))/1024/1024) AS used_mb,
    ROUND(SUM(NVL(free.bytes,0))/1024/1024) AS free_mb,
    ROUND((1 - (SUM(NVL(free.bytes,0))/SUM(df.bytes)))*100) AS used_pct
FROM 
    dba_data_files df,
    (SELECT file_id, SUM(bytes) AS bytes FROM dba_free_space GROUP BY file_id) free
WHERE 
    df.file_id = free.file_id(+)
GROUP BY 
    df.tablespace_name
ORDER BY 
    used_pct DESC;

-- Kontrola parametrov dátových súborov (autoextend, max veľkosť)
-- Poznámka: Používateľ má autoextend nastavený na max 32GB
SELECT 
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes/1024/1024) AS current_mb,
    df.autoextensible,
### Správa tablespaceov a úložiska

**Dôležité:** Tablespace "kritická" hodnota % neznamená krízu, ak sú dátové súbory nastavené na autoextend s max. veľkosťou (napr. 32GB). Vždy kontrolovať `dba_data_files.maxbytes` a `autoextensible`.

```sql
-- Voľné miesto v tablespacoch (OPRAVENÉ - odstránený ORA-00918)
SELECT 
    df.tablespace_name, 
    ROUND(SUM(df.bytes)/1024/1024) AS total_mb,
    ROUND(SUM(df.bytes - NVL(free.bytes,0))/1024/1024) AS used_mb,
    ROUND(SUM(NVL(free.bytes,0))/1024/1024) AS free_mb,
    ROUND((1 - (SUM(NVL(free.bytes,0))/SUM(df.bytes)))*100) AS used_pct
FROM 
    dba_data_files df,
    (SELECT file_id, SUM(bytes) AS bytes FROM dba_free_space GROUP BY file_id) free
WHERE 
    df.file_id = free.file_id(+)
GROUP BY 
    df.tablespace_name;

-- Parametre dátových súborov (autoextend, max. veľkosť)
-- POZNÁMKA: v$datafile NEMÁ stĺpce maxbytes, autoextensible - tie sú v dba_data_files
-- Na získanie block_size je potrebné join s dba_tablespaces
SELECT 
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes/1024/1024) AS current_mb,
    df.autoextensible,
    ROUND(df.increment_by * ts.block_size / 1024 / 1024, 1) AS increment_mb,
    ROUND(df.maxbytes/1024/1024) AS max_mb,
    ROUND((df.bytes/df.maxbytes)*100, 1) AS pct_of_max
FROM 
    dba_data_files df
JOIN 
    dba_tablespaces ts ON df.tablespace_name = ts.tablespace_name
WHERE 
    df.tablespace_name IN ('SYSTEM', 'SYSAUX', 'USERS', 'INDX', 'UNDOTBS1')
ORDER BY 
    df.tablespace_name, df.file_name;
```

### Správa používateľov a privilégií
```sql
-- Zoznam používateľov
SELECT username, account_status, created, 
       profile, default_tablespace
FROM dba_users
ORDER BY created DESC;

-- Privilégiá konkrétneho používateľa
SELECT * FROM dba_sys_privs WHERE grantee = 'USERNAME';
SELECT * FROM dba_tab_privs WHERE grantee = 'USERNAME';
SELECT * FROM dba_role_privs WHERE grantee = 'USERNAME';

-- Zamknutí používatelia
SELECT username, account_status, lock_date
FROM dba_users 
WHERE account_status LIKE '%LOCKED%';
```

## Monitoring výkonu a optimalizácia

### Databázové zámky - Pravidlo reportovania
**Používateľova korekcia:** Reportovať IBA keď zámky blokujú iné session!
- ✅ **Reportovať:** TX zámky s blocking, TM zámky s čakaním, sessions s `REQUEST_MODE != None`
- ❌ **Ignorovať:** AE (Edition) zámky - sú benigné (súvisia s `ORA$BASE` objektom)
- Použiť dotaz na blokujúce zámky (l1.block = 1 AND l2.request > 0)

### Kill Session
**Používateľova požiadavka:** Ak je potrebné zabiť session, použiť nasledovnú procedúru:
```sql
-- Kill session cez sys.kill_session procedúru
BEGIN
  sys.kill_session(p_sid => SID, p_serial => SERIAL#);
END;
/
```
Kde `SID` a `SERIAL#` sú z výstupu dopytu na blokujúce zámky (stĺpce `blocker` obsahuje `sid,serial#`).
Príklad pre blocker session `123,456`:
```sql
BEGIN
  sys.kill_session(p_sid => 123, p_serial => 456);
END;
/
```

```sql
-- Kontrola IBA blokujúcich zámkov (použiť tento dotaz!)
SELECT 
    l1.sid || ',' || s1.serial# AS blocker,
    s1.username AS blocker_user,
    l2.sid || ',' || s2.serial# AS waiter,
    s2.username AS waiter_user,
    o.object_name,
    o.object_type
FROM 
    v$lock l1,
    v$lock l2,
    v$session s1,
    v$session s2,
    dba_objects o
WHERE 
    l1.block = 1 
    AND l2.request > 0
    AND l1.id1 = l2.id1
    AND l1.id2 = l2.id2
    AND l1.sid = s1.sid
    AND l2.sid = s2.sid
    AND l1.id1 = o.object_id(+);

-- AE zámky (Edition locks) - IGNOROVAŤ, sú benigné
-- Tieto zámky majú type='AE' a object_name='ORA$BASE'
## Monitoring výkonu a optimalizácia

### SQL Performance Troubleshooting (Sekcia C v dokumentácii)

**Dôležité o časovom rámci:**
- `v$system_event` obsahuje **kumulatívne údaje od posledného reštartu inštancie** (overiť cez `SELECT startup_time FROM v$instance`)
- Pre aktuálny stav použiť `v$session_wait` alebo obmedziť časový rozsah

```sql
-- Aktuálne spustené SQL dotazy
SELECT sid, serial#, username, sql_id, 
       ROUND(elapsed_time/1000000) AS elapsed_sec,
       sql_text
FROM v$session s
JOIN v$sql sq ON s.sql_id = sq.sql_id
WHERE s.status = 'ACTIVE' AND s.username IS NOT NULL;

-- História SQL dotazov (AWR)
SELECT sql_id, executions, 
       ROUND(elapsed_time/1000000) AS total_elapsed_sec,
       ROUND(cpu_time/1000000) AS cpu_sec,
       ROUND(disk_reads) AS disk_reads,
       ROUND(buffer_gets) AS buffer_gets
FROM dba_hist_sqlstat
WHERE snap_id = (SELECT MAX(snap_id) FROM dba_hist_snapshot)
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;

-- Wait events (kumulatívne od štartu inštancie)
SELECT event, total_waits, time_waited,
       ROUND(time_waited_micro/1000000) AS time_waited_sec
FROM v$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited_micro DESC
FETCH FIRST 10 ROWS ONLY;

-- Top SQL podľa diskových čítaní
SELECT sql_id, sql_text, disk_reads, 
       executions, buffer_gets
FROM v$sqlarea
WHERE disk_reads > 1000
ORDER BY disk_reads DESC
FETCH FIRST 20 ROWS ONLY;
```

### Databázové zámky (Locks)

**Používateľova obľúbená pravidlo:** Reportovať IBA keď zámky **blokujú iné session**!
- AE (Edition) zámky sú **benigné** - ignorovať
- TX, TM zámky s `REQUEST_MODE != None` alebo `BLOCK > 0` - HLÁSIŤ!

```sql
-- BLOKUJÚCE ZÁMKY (jediné, ktoré reportovať)
SELECT 
    l1.sid || ',' || s1.serial# AS blocker,
    s1.username AS blocker_user,
    l2.sid || ',' || s2.serial# AS waiter,
    s2.username AS waiter_user,
    o.object_name,
    o.object_type
FROM 
    v$lock l1,
    v$lock l2,
    v$session s1,
    v$session s2,
    dba_objects o
WHERE 
    l1.block = 1 
    AND l2.request > 0
    AND l1.id1 = l2.id1
    AND l1.id2 = l2.id2
    AND l1.sid = s1.sid
    AND l2.sid = s2.sid
    AND l1.id1 = o.object_id(+);

-- Všetky zámky (pre informáciu, NIE reportovať ak nie sú blokujúce)
SELECT 
    s.sid, s.serial#, s.username, s.status, 
    l.type, l.id1, l.id2, 
    DECODE(l.lmode, 0, 'None', 1, 'Null', 2, 'Row-S', 3, 'Row-X', 
        4, 'Share', 5, 'S/Row-X', 6, 'Exclusive', 'Unknown') AS lock_mode,
    DECODE(l.request, 0, 'None', 1, 'Null', 2, 'Row-S', 3, 'Row-X', 
        4, 'Share', 5, 'S/Row-X', 6, 'Exclusive', 'Unknown') AS request_mode
FROM 
    v$lock l
JOIN 
    v$session s ON l.sid = s.sid
LEFT JOIN 
    dba_objects o ON l.id1 = o.object_id
WHERE 
    l.type != 'MR'  -- Filter out Media Recovery locks
    AND s.username IS NOT NULL
ORDER BY s.sid;
```

### Indexy a optimalizácia
```sql
-- Nevyužité indexy
SELECT index_name, table_name, monitoring, 
       used, start_monitoring, end_monitoring
FROM v$object_usage
WHERE used = 'NO';

-- Fragmentované indexy (potrebujú rebuild)
SELECT index_name, table_name, 
       ROUND((del_lf_rows_len / (lf_rows_len + del_lf_rows_len))*100) AS frag_pct
FROM index_stats
WHERE del_lf_rows_len > 0;

-- Chýbajúce indexy (dotazy s full table scan)
SELECT sql_id, sql_text, executions, 
       ROUND(disk_reads/executions) AS reads_per_exec
FROM v$sqlarea
WHERE executions > 10 
  AND sql_text NOT LIKE '%v$sql%'
  AND plan_hash_value IN (
    SELECT plan_hash_value FROM v$sql_plan 
    WHERE operation = 'TABLE ACCESS' AND options = 'FULL'
  );
```

## Audit a bezpečnosť

### Standardný audit
```sql
-- Zapnutie auditu
ALTER SYSTEM SET audit_trail=DB SCOPE=SPFILE;
AUDIT ALL BY ACCESS;
AUDIT SELECT TABLE, INSERT TABLE, DELETE TABLE, UPDATE TABLE BY ACCESS;

-- Zoznam auditovaných akcií
SELECT * FROM dba_stmt_audit_opts;
SELECT * FROM dba_priv_audit_opts;

-- Audit záznamy
SELECT username, action_name, obj_name, 
       timestamp, returncode
FROM dba_audit_trail
WHERE timestamp > SYSDATE - 7
ORDER BY timestamp DESC
FETCH FIRST 50 ROWS ONLY;
```

### Unified Audit (12c+)
```sql
-- Status unified audit
SELECT * FROM unified_audit_trail
WHERE event_timestamp > SYSTIMESTAMP - INTERVAL '7' DAY
ORDER BY event_timestamp DESC;

-- Cleanup starých audit záznamov
BEGIN
  DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
    audit_trail_type => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    use_last_arch_timestamp => TRUE
  );
END;
/
```

## Data Pump operácie (Sekcia 8 v dokumentácii)

SQLcl podporuje Data Pump priamo cez príkazy:

```sql
-- Export full databázy
expdp system/password@ORCL FULL=y DIRECTORY=DATA_PUMP_DIR 
       DUMPFILE=full_%U.dmp LOGFILE=full_export.log PARALLEL=4

-- Export konkrétneho schemas
expdp system/password SCHEMAS=hr,scott DIRECTORY=DATA_PUMP_DIR 
       DUMPFILE=schema_%U.dmp LOGFILE=schema_export.log

-- Import s remappingom
impdp system/password DIRECTORY=DATA_PUMP_DIR 
       DUMPFILE=schema_01.dmp REMAP_SCHEMA=hr:hr_new 
       REMAP_TABLESPACE=users:new_ts

-- Import tabuľky
impdp system/password TABLES=hr.employees,hr.departments 
       DIRECTORY=DATA_PUMP_DIR DUMPFILE=tables.dmp
```

## SQLcl špecifické funkcie

### Formatovanie výstupu
```sql
-- Nastavenie formátu (podobné SQL*Plus, ale modernejšie)
SET SQLFORMAT CSV    -- CSV výstup
SET SQLFORMAT JSON   -- JSON výstup
SET SQLFORMAT XML    -- XML výstup
SET SQLFORMAT ANSICONSOLE  -- Čitateľný formát

-- Priamy export do súboru
SPOOL /tmp/output.csv
SELECT * FROM employees;
SPOOL OFF
```

### Scripting a JavaScript (25.4 novinka)
```javascript
// SQLcl podporuje JavaScript od verzie 23.4+
// Príklad v SQLcl:
// script
const conn = await sqlcl.getConnection();
const result = await conn.execute("SELECT COUNT(*) FROM employees");
console.log("Employee count: " + result.rows[0][0]);
// endscript
```

### Liquibase integrácia (Sekcia 5)
```bash
# Spustenie Liquibase changelog cez SQLcl
sql system/password@ORCL <<EOF
lb update -changelog-file=changelog.xml
lb rollback -tag=v1.0
EOF
```

## Automatizácia a Scheduler (Sekcia 4)

```sql
-- Vytvorenie jobu v Oracle Scheduler
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name   => 'COLLECT_STATS_JOB',
    job_type   => 'PLSQL_BLOCK',
    job_action => 'BEGIN DBMS_STATS.GATHER_DATABASE_STATS; END;',
    start_date => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=2',
    enabled    => TRUE
  );
END;
/

-- Monitorovanie jobov
SELECT job_name, status, run_duration, 
       actual_start_date, additional_info
FROM dba_scheduler_job_run_details
WHERE actual_start_date > SYSDATE - 1
ORDER BY actual_start_date DESC;
```

## Rýchle kontrolné skripty (Health Checks)

### Daily Health Check
**Poznámka:** Používateľ má autoextend nastavený na max 32GB. High % využitia nie je krízové, ak sú súbory nastavené na autoextend s dostatok max. priestoru.

```sql
-- 1. Tablespace usage alert (upravené pre autoextend prostredie)
-- Toto je len varovanie, nie kríza ak je autoextend=YES a maxbytes >> bytes
SELECT tablespace_name, 
       ROUND(SUM(df.bytes)/1024/1024) AS total_mb,
## Rýchle kontrolné skripty (Health Checks)

### Daily Health Check
```sql
-- 1. Filesystem a ASM voľné miesto
SELECT name, total_mb, free_mb, 
       ROUND((free_mb/total_mb)*100) AS free_pct
FROM v$asm_diskgroup;

-- 2. Sessions
SELECT COUNT(*) AS total_sessions,
       SUM(CASE WHEN status='ACTIVE' THEN 1 ELSE 0 END) AS active_sessions
FROM v$session;

-- 3. Waits (kumulatívne od štartu inštancie!)
SELECT event, total_waits, time_waited_micro/1000000 AS time_waited_sec
FROM v$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited_micro DESC
FETCH FIRST 5 ROWS ONLY;

-- 4. Tablespace usage alert (skontrolovať aj autoextend!)
SELECT df.tablespace_name, 
       ROUND((1 - (NVL(free.bytes,0)/SUM(df.bytes)))*100) AS used_pct,
       df.autoextensible,
       ROUND(df.maxbytes/1024/1024) AS max_mb
FROM 
    dba_data_files df,
    (SELECT file_id, SUM(bytes) bytes FROM dba_free_space GROUP BY file_id) free
WHERE 
    df.file_id = free.file_id(+)
GROUP BY 
    df.tablespace_name, df.autoextensible, df.maxbytes
HAVING 
    (1 - (NVL(free.bytes,0)/SUM(df.bytes))) > 0.85;
```

## Oracle SQLcl MCP Server - kedy použiť?

**Výskum z session:** Študovaná dokumentácia pre Oracle SQLcl MCP Server (sekcia 3 v používateľskej príručke).

**Záver - pre DBA prácu NIE JE odporúčaný MCP Server:**
- ❌ **Pomalší** - AI generuje SQL → posiela cez MCP → vykoná (namiesto priameho vykonania)
- ❌ **Bezpečnostné riziká** - "When you grant a large language model (LLM) access to your database, it introduces significant security risks"
- ❌ **Nadbytočný** - DBA vie presne čo chce, nepotrebuje AI generovanie SQL

**Kedy MÁ zmysel MCP Server:**
- ✅ Pre ne-databázových používateľov (manažéri)
- ✅ Prirodzený jazyk ("vysvetli mi stav tablespaces")
- ✅ Automatizované reporty cez AI

**Odporúčanie:** Ostať pri priamom SQLcl (`sql -name <DB>`) + tento skill.

## Poučenia z praxe (Pitfalls)

1. **Chyba ORA-00918 v skillu:** Stĺpec `bytes` je v `dba_data_files` aj v poddotaze - treba použiť aliasy (`df.bytes`)
2. **`v$datafile` vs `dba_data_files`:** 
   - `v$datafile` - informácie o súboroch (current bytes, status)
   - `dba_data_files` - aj `autoextensible`, `increment_by`, `maxbytes`, `block_size` (cez join s `dba_tablespaces`)
3. **Wait events časový rámec:** `v$system_event` je **kumulatívny od štartu inštancie** (overiť cez `v$instance.startup_time`)
4. **Tablespace "kríza":** % využitia neznamená krízu, ak sú súbory na `autoextend` s `maxbytes` (napr. 32GB)
5. **Reportovanie zámkov:** IBA keď blokujú iné session (BLOCK=1, REQUEST>0). AE zámky ignorovať.

## Analýza archívnych logov a identifikácia zdrojov

### Archivelog generation analýza
Používateľ očakáva vizuálnu analýzu v polhodinových intervaloch s kumulatívnym grafom.

**Dotaz na archivelog generation v polhodinových intervaloch (Oracle 11g/12c+):**
```sql
-- Archivelog generation v polhodinových intervaloch za dnešný deň
SELECT 
    TO_CHAR(TRUNC(first_time, 'HH') + 
        FLOOR(TO_NUMBER(TO_CHAR(first_time, 'MI')) / 30) * 30 / 1440, 
        'HH24:MI') AS time_slot,
    ROUND(SUM(blocks * block_size) / 1024 / 1024, 2) AS mb_generated
FROM v$archived_log
WHERE first_time >= TRUNC(SYSDATE)
  AND first_time < TRUNC(SYSDATE) + 1
  AND dest_id = 1
GROUP BY 
    TRUNC(first_time, 'HH') + 
    FLOOR(TO_NUMBER(TO_CHAR(first_time, 'MI')) / 30) * 30 / 1440
ORDER BY 
    TRUNC(first_time, 'HH') + 
    FLOOR(TO_NUMBER(TO_CHAR(first_time, 'MI')) / 30) * 30 / 1440;
```

**Vizualizácia:**
- Používateľ preferuje **HTML grafy s Chart.js** (ak nie je matplotlib dostupný)
- Generovať interaktívne HTML s:
  - Bar chart (MB per 30min interval)
  - Line chart (kumulatívny súčet)
  - Zvýraznenie špičiek (červená > 20GB, oranžová > 10GB)
- Cesty: `/tmp/cloudX_archivelogs.html`, `/tmp/cloudX_cumulative_archivelogs.html`

### Identifikácia používateľov zodpovedných za špičky
Pri špičkách v archivelogoch použiť AWR dáta na identifikáciu "viníka":

**1. Top SQL v časoch špičiek (dba_hist_sqlstat + dba_hist_snapshot):**
```sql
-- Top SQL podľa počtu executions v konkrétnom čase (Oracle 11g)
SELECT * FROM (
    SELECT 
        TO_CHAR(hss.begin_interval_time, 'HH24:MI') AS snap_time,
        dhst.sql_id,
        SUBSTR(dhst.sql_text, 1, 100) AS sql_text_short,
        dhs.executions_delta AS executions,
        dhs.rows_processed_delta AS rows_processed
    FROM dba_hist_sqlstat dhs
    JOIN dba_hist_snapshot hss ON dhs.snap_id = hss.snap_id
    JOIN dba_hist_sqltext dhst ON dhs.sql_id = dhst.sql_id
    WHERE hss.begin_interval_time >= TRUNC(SYSDATE)
      AND EXTRACT(HOUR FROM CAST(hss.begin_interval_time AS TIMESTAMP)) IN (2, 10, 13, 19) -- hodiny špičiek
      AND dhs.executions_delta > 0
    ORDER BY dhs.executions_delta DESC
)
WHERE ROWNUM <= 20;
```

**2. Top používatelia v časoch špičiek (dba_hist_active_sess_history):**
```sql
-- Kto má najviac active session samples v časoch špičiek
SELECT 
    TO_CHAR(h.sample_time, 'HH24') AS hour,
    u.username,
    COUNT(*) AS samples
FROM dba_hist_active_sess_history h
JOIN dba_users u ON h.user_id = u.user_id
WHERE h.sample_time >= TRUNC(SYSDATE)
  AND TO_CHAR(h.sample_time, 'HH24') IN ('02','10','13','19')
GROUP BY TO_CHAR(h.sample_time, 'HH24'), u.username
ORDER BY hour, samples DESC;
```

**3. Aktuálne transakcie a ich používatelia:**
```sql
SELECT 
    s.username, s.sid, s.program, t.start_time,
    ROUND(t.used_ublk * (SELECT value FROM v$parameter WHERE name='db_block_size')/1024/1024, 2) AS undo_mb
FROM v$transaction t
JOIN v$session s ON t.ses_addr = s.saddr
ORDER BY t.used_ublk DESC;
```

**Zistenia z CLOUD1 (2026-05-07):**
- Špičky: 02:00 (22GB), 10:00 (27GB), 13:00 (27GB), 19:30 (39GB)
- Hlavní "viníci": **JKOMARNO** (nočné/popoludňajšie batch procesy), **KINEK** (DML operácie, UPDATE OBJ_ODB_L)
- Systémový **SYS**: masívne `insert into argument$` (PL/SQL kompilácia)

## Časté problémy a riešenia

1. **ORA-12154: TNS:could not resolve the connect identifier**
   - Skontroluj TNS_ADMIN premennú a tnsnames.ora

2. **ORA-12541: TNS:no listener**
   - Skontroluj či beží listener: `lsnrctl status`

3. **Tablespace 100% full**
   - Pridaj dátový súbor: `ALTER TABLESPACE users ADD DATAFILE '/path/user02.dbf' SIZE 100M AUTOEXTEND ON;`

4. **Pomalé dotazy**
   - Skontroluj explain plan: `EXPLAIN PLAN FOR <sql>; SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);`

5. **ORA-12170: Cannot connect. TCP connect timeout**
   - Skontroluj dostupnosť hosta (ping, timeout)
   - Over správnu IP adresu a port (štandardne 1521)
   - Skontroluj firewall nastavenia pre port 1521

## Zdroje

- Oficiálna dokumentácia: https://docs.oracle.com/en/database/oracle/sql-developer-command-line/25.4/sqcug/index.html
- PDF manuál: https://docs.oracle.com/en/database/oracle/sql-developer-command-line/25.4/sqcug/oracle-sqlcl-users-guide.pdf
- MCP Server dokumentácia (sekcia 3): Pre integráciu s AI agentmi