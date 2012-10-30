create or replace package generate as 

  function history_objects(p_table_name in varchar2) return varchar2;
  function history_table(p_table_name in varchar2) return varchar2;
  function history_columns(p_table_name in varchar2) return varchar2;
  function history_sequence(p_table_name in varchar2) return varchar2;
  function history_id_trigger(p_table_name in varchar2) return varchar2;
  function history_trigger(p_table_name in varchar2) return varchar2;
  
  function audit_objects(p_table_name in varchar2) return varchar2; 
  function audit_columns(p_table_name in varchar2) return varchar2; 
  function audit_trigger(p_table_name in varchar2) return varchar2; 


  function data_type_definition(p_data_type in varchar2, p_data_length in varchar2, p_data_precision in varchar2, p_data_scale in varchar2) return varchar2;

  function nl(p in varchar2 default null) return varchar2;
end generate;


create or replace package body generate as

  function history_objects(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
    l_history number;
  begin
    select count(*) into l_history from user_tables where table_name = p_table_name || '_HISTORY';
    if l_history = 0 then
      l_sql :=  nl(history_table(p_table_name)) || nl(history_sequence(p_table_name)) || nl(history_id_trigger(p_table_name));
    else 
      l_sql := nl(history_columns(p_table_name));
    end if;
    l_sql :=  l_sql || nl(history_trigger(p_table_name));
    return l_sql;
  end history_objects;


  function history_table(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql :=          nl('CREATE TABLE ' || p_table_name || '_HISTORY (');
    l_sql := l_sql || nl('ID NUMBER NOT NULL,');
    
    for c in (
      select   decode(column_name, 'ID', p_table_name || '_ID', column_name) column_name
             , generate.data_type_definition(data_type, data_length, data_precision, data_scale) data_type
             , decode(nullable, 'N', 'NOT NULL') nullable 
      from     user_tab_columns
      where    table_name = p_table_name
      order by column_id) 
      loop
        l_sql := l_sql || nl(c.column_name || ' ' || c.data_type || ' ' || c.nullable || ',');
      end loop;
      
    l_sql := l_sql || nl('constraint ' || p_table_name || '_HISTORY_PK PRIMARY KEY(ID)');
    l_sql := l_sql || ');';
    return l_sql;
  end history_table;


  function history_columns(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql := '';
    
    for c in (
      select   column_name, decode(nullable, 'N', 'NOT NULL') nullable,
               generate.data_type_definition(data_type, data_length, data_precision, data_scale) data_type 
      from     user_tab_columns t 
      where    table_name = p_table_name 
      and not exists 
        (select 'x' from user_tab_columns c
         where  c.column_name = t.column_name 
         and    c.table_name = t.table_name||'_HISTORY') )
    loop
      l_sql := l_sql || nl('ALTER TABLE ' || p_table_name || '_HISTORY ADD (' || c.column_name || ' ' || c.data_type || ' ' || c.nullable || ');');
    end loop;
      
    return l_sql;
  end history_columns;


  function history_trigger(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
    cursor c1 is 
      select   column_name, column_id 
      from     user_tab_columns 
      where    table_name = p_table_name 
      order by column_id; 
  begin
    l_sql :=          nl('CREATE OR REPLACE TRIGGER ' || p_table_name || '_HISTORY');
    l_sql := l_sql || nl('  after update or delete on ' || p_table_name);
    l_sql := l_sql || nl('  for each row');
    l_sql := l_sql || nl('BEGIN');
    l_sql := l_sql || nl('  insert into ' || p_table_name || '_HISTORY (');
    
    for c in c1 loop 
      if c.column_id > 1 then 
        l_sql := l_sql || ', ';
      end if;
      
      if c.column_name = 'ID' then
        l_sql := l_sql || nl(p_table_name || '_ID');
      else
        l_sql := l_sql || nl(c.column_name);
      end if;
    end loop;
      
    l_sql := l_sql || nl(') values (');

    for c in c1 loop 
      if c.column_id > 1 then 
        l_sql := l_sql || ', ';
      end if;
      l_sql := l_sql || nl(':old.' || c.column_name);
    end loop;
      
    l_sql := l_sql || nl(');');
    l_sql := l_sql || nl('END;');
    l_sql := l_sql || '/';
    return l_sql;
  end history_trigger;


  function history_sequence(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql :=          'CREATE SEQUENCE ' || p_table_name || '_HISTORY_SEQ;';
    return l_sql;
  end history_sequence;


  function history_id_trigger(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql :=          nl('CREATE OR REPLACE TRIGGER ' || p_table_name || '_HISTORY_ID ');
    l_sql := l_sql || nl('  before insert on ' || p_table_name) ;
    l_sql := l_sql || nl('  for each row');
    l_sql := l_sql || nl('BEGIN');
    l_sql := l_sql || nl('  if :new.id is null then');
    l_sql := l_sql || nl('    select ' || p_table_name || '_HISTORY_SEQ.nextval into :new.id from dual;');
    l_sql := l_sql || nl('  end if;');
    l_sql := l_sql || nl('END;');
    l_sql := l_sql || '/';
    
    return l_sql;
  end history_id_trigger;

/* ***************
 * A U D I T I N G
 * ***************
 */
 
  function audit_objects(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql :=  nl(audit_columns(p_table_name)) || 
              nl(audit_trigger(p_table_name)); 
    return l_sql;
  end audit_objects;


  function audit_columns(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql :=          nl('ALTER TABLE ' || p_table_name || ' ADD (');
    l_sql := l_sql || nl('  created_on date, ') ;
    l_sql := l_sql || nl('  created_by varchar2(100), ');
    l_sql := l_sql || nl('  modified_on date, ') ;
    l_sql := l_sql || nl('  modified_by varchar2(100)');
    l_sql := l_sql || ');';
    
    return l_sql;
  end audit_columns;


  function audit_trigger(p_table_name in varchar2) return varchar2 is 
    l_sql varchar2(32767);
  begin
    l_sql :=          nl('CREATE OR REPLACE TRIGGER ' || p_table_name || '_AUDIT');
    l_sql := l_sql || nl('  before insert or update on ' || p_table_name) ;
    l_sql := l_sql || nl('  for each row');
    l_sql := l_sql || nl('BEGIN');
    l_sql := l_sql || nl('  if inserting then');
    l_sql := l_sql || nl('    :new.created_on := sysdate;');
    l_sql := l_sql || nl('    :new.created_by := nvl(v(''APP_USER''),USER);');
    l_sql := l_sql || nl('  end if;');
    l_sql := l_sql || nl('  :new.modified_on := sysdate;');
    l_sql := l_sql || nl('  :new.modified_by := nvl(v(''APP_USER''),USER);');
    l_sql := l_sql || nl('END;');
    
    l_sql := l_sql || '/';
    
    return l_sql;
  end audit_trigger;


  function data_type_definition(p_data_type in varchar2, p_data_length in varchar2, p_data_precision in varchar2, p_data_scale in varchar2) 
    return varchar2 is
  begin
    if p_data_type in ('NUMBER', 'DATE') then
      if p_data_precision is not null then
        return p_data_type || '(' || p_data_precision || ', ' || nvl(p_data_scale,0) || ')';
      else
        return p_data_type;
      end if;
   else
     return p_data_type || '(' || p_data_length || ')';
   end if;
  end data_type_definition;
  
  
  function nl(p in varchar2 default null) return varchar2 is
  begin
    return p || chr(13)||chr(10);
  end nl;

end generate;