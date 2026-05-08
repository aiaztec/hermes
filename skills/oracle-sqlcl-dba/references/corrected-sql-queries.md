# Corrected SQL Queries - Oracle SQLcl DBA

Queries that were debugged and fixed during session on 2026-05-03.

## Tablespace Usage (Fixed ORA-00918)

Original query had ambiguous column `bytes` in the join. Fixed by aliasing properly:

```sql
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
```

## Datafile Parameters (Fixed ORA-00904)

`v$datafile` doesn't have `maxbytes` or `block_size`. Use `dba_data_files` joined with `dba_tablespaces`:

```sql
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

## Blocking Locks Only (User Rule: Report Only Blocking)

Ignore AE (Edition) locks - they are benign.

```sql
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
```

## Efficient Connection Syntax

User correction: Use `sql -name` instead of heredoc:

```bash
# Efficient (preferred)
sql -name CLOUD19B <<EOF
SELECT * FROM v\$database;
exit
EOF

# Not efficient (avoid)
sql /nolog <<EOF
conn CLOUD19B
...
exit
EOF
```

## Autoextend Note

User environment: Datafiles have autoextend ON with max 32GB (32768 MB).
High tablespace % usage is not critical if autoextend has room to grow.