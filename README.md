SQL-Generator
=============

Generates common database objects from Oracle data dictionary 

General Usage
-------------
The Generate package contains a number of functions that return sql statements that can be combined into a sql script. 
Most of the functions take a TABLE_NAME as a single parameter so you can invoke them from any 
select statement that includes a TABLE_NAME column.

e.g.

select generate.history_table(table_name) from user_tables; 

Auditing
--------
The auditing generators will generate sql for a table that will add a standard set of auditing columns 
to a table (created_by/on and modified_by/on) and create a trigger to populate them.

generate.audit_columns(table_name) - Generates alter table statement to add auditing columns to table
generate.audit_trigger(table_name) - Generates trigger statement to populate auditing columns in table
generate.audit_objects(table_name) - Generates both the alter table and trigger statements for a specified table

n.b. the trigger assumes the Oracle Application Express database objects are present to support v('USER').

History
-------
The history generators will generate sql for a table that will create a history table with an indentical structure 
as the specified table and a trigger to populate the history table when any changes occur on the main table.

generate.history_table(table_name) - Generate a table called TABLE_NAME_HISTORY with an identical structure as the main table
generate.history_columns(table_name) - Generates alter table statements to bring the history table into line with the main table
generate.history_trigger(table_name) - Generates a trigger on the main table to save any changes to the history table
generate.history_objects(table_name) - Generates all the create table or alter table statements, triggers and sequences to add history support to a table

Notes
-----
This package was developed and tested against an Oracle 11g database.
