-- See blog post: https://sqlpal.blogspot.com/2019/05/do-you-have-rarely-used-indexes-that.html
/*

Here is an a version of query to find unused or lesser used indexes. It looks for non-unique indexes with large number of DMLs with ratio of writes vs reads is relatively high (I am using a factor of 10 but at this point its an arbitrary starting point).
*/


WITH cte
     AS (SELECT Db_name(iu.database_id)                   db_name,
                Object_name(iu.object_id, iu.database_id) object_name,
                i.NAME                                    index_name,
                i.type_desc                               index_type,
                Sum(iu.user_seeks) + Sum(iu.user_scans)
                + Sum(iu.user_lookups)                    total_user_reads,
                Sum(iu.user_updates)                      total_user_writes
         FROM   sys.dm_db_index_usage_stats iu
                INNER JOIN sys.indexes i ON i.object_id = iu.object_id
                           AND i.index_id = iu.index_id
         WHERE  iu.database_id = Db_id()
                AND i.index_id > 0 
                AND i.is_unique = 0
         GROUP  BY iu.database_id,
                   iu.object_id,
                   i.NAME,
                   i.type_desc)
SELECT *,
       total_user_writes / total_user_reads write_to_read_ratio
FROM   cte
WHERE  1 = 1
       AND total_user_writes > 1000000 
       AND total_user_reads  < 1000
       AND ( total_user_writes / NULLIF(total_user_reads,0) > 10
              OR total_user_writes / total_user_reads IS NULL )
ORDER  BY write_to_read_ratio DESC
