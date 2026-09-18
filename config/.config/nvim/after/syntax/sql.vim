" Make SELECT and other DML statements match sqlKeyword color
hi! link sqlStatement sqlKeyword

" Add QUALIFY (Snowflake/BigQuery window filter clause)
" Add OVER and PARTITION (window function keywords)
syn keyword sqlKeyword qualify over partition
