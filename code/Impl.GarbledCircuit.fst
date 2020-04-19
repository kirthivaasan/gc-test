module Impl.GarbledCircuit

module B = LowStar.Buffer
module ST = FStar.HyperStack.ST
module HS = FStar.HyperStack
module S = FStar.Seq

module U32 = FStar.UInt32
module U64 = FStar.UInt64

open Hacl.Curve25519_64

let square (x: UInt64.t): UInt64.t = let open FStar.UInt64 in x *%^ x
let quad (x: UInt64.t): UInt64.t = square (square x)
