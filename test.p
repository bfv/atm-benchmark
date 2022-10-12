def var i as int no-undo.
repeat:
   i = 0.
   do transaction:
   for each account:
       i = i + 1.
       if i gt 5000 then leave.
       delete account.
       end.
   end.
end.
