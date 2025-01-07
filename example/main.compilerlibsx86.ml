(* Access fields provided by the (x86_64) compiler libs *)

let _ =
  Printf.printf "allow_unaligned_access = %b\n" Arch.allow_unaligned_access;
  Printf.printf "win64 = %b\n" Arch.win64
