See t/plsql.t for lots of examples.

begin dbms_output.enable(); end;
begin dbms_output.put_line(:thing); end;
begin dbms_output.get_line(:buffer, :status); end;

