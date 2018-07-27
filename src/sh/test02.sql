\set id random(1,10000000)  
select * 
from t1 
  join t2 using (id) 
  join t3 using (id) 
  join t4 using (id) 
  join t5 using (id) 
  join t6 using (id) 
  join t7 using (id) 
  join t8 using (id) 
  join t9 using (id) 
  join t10 using (id) 
where t1.id=:id;  
