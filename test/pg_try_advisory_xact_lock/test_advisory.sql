\set id random(1, 1)
update t1 set info=now()::text where id=:id and pg_try_advisory_xact_lock(:id);  