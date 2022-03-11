module Id = struct 
  type t = int64

  let t = Irmin.Type.int64

  let to_string : t -> string = 
    Fmt.to_to_string (Irmin.Type.pp_json t)

  let compare = Int64.compare

  let of_int = Int64.of_int

  let random = Random.int64 10000000000L
end

type id = Id.t
let id = Id.t

type item_req =
  { _ol_num: int32; (* seq no *)
    _ol_i_id: id; 
    _ol_supply_w_id: id; _ol_qty: int32
  }

let minf f l = 
  List.fold_left 
    (fun acc x -> match acc with
       | None -> Some x
       | Some x' -> if Int64.compare (f x) (f x') < 0 
                  then Some x else acc)
    None l

module Warehouse = struct
  type t = { w_id: Id.t; w_ytd: int32 }
  [@@deriving irmin]

  let merge lca {w_ytd=y1; _} {w_ytd=y2; _} =  
    {lca with w_ytd = SInt32.merge lca.w_ytd y1 y2}

  (* This boiler-plate implements the Content.TYPE signature so that
     Warehouse, District, etc. can be used as values in Mrbmap *)
  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module District = struct 
  type t = { d_w_id: Id.t; d_id: Id.t; d_ytd: int32 }
  [@@deriving irmin]

  let merge lca {d_ytd=y1; _} {d_ytd=y2; _} =  
    {lca with d_ytd = SInt32.merge lca.d_ytd y1 y2}

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module Order = struct
  type t =
    { o_w_id: Id.t;
      o_d_id: Id.t;
      o_id: Id.t;
      o_c_id: Id.t; 
      o_ol_cnt: int32; 
      o_carrier_id: bool
    }
  [@@deriving irmin]

  let merge lca ({o_carrier_id=b1; _} as v1) 
                ({o_carrier_id=b2; _} as v2) =  
    if lca.o_carrier_id = true
    then (assert (lca=v1 && v1=v2); lca)
    else {lca with o_carrier_id = b1 || b2}

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module NewOrder = struct 
  type t = {no_w_id: Id.t; no_d_id: Id.t; no_o_id: Id.t}
  [@@deriving irmin]

  let merge _ _ _ = failwith "new_order is immutable"

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module OrderLine = struct 
  type t =
    { ol_w_id: Id.t;
      ol_d_id: Id.t; 
      ol_o_id: Id.t;
      ol_i_id: Id.t;
      ol_num: int32; 
      ol_supply_w_id: Id.t;
      ol_amt: int32;
      ol_qty: int32;
      ol_delivery_d: float option
    }
  [@@deriving irmin]

  let merge lca {ol_delivery_d=d1; _} {ol_delivery_d=d2; _} = 
    let d = match d1,d2 with 
      | None,None -> None 
      | Some d1,None -> Some d1 
      | None,Some d2 -> Some d2
      | Some d1, Some d2 -> Some (min d1 d2) in
    {lca with ol_delivery_d=d}

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module Item = struct
  type t = {i_id: Id.t; i_name: string; i_price: int32}
  [@@deriving irmin]

  let merge _ _ _ = failwith "Item is immutable"

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module Hist = struct 
  type t =
    { h_c_id: Id.t;
      h_c_d_id: Id.t;
      h_c_w_id: Id.t; 
      h_d_id: Id.t;
      h_w_id: Id.t;
      h_amt: int32
    }
  [@@deriving irmin]

  let merge _ _ _ = failwith "Hist is immutable"

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module Stock = struct 
  type t =
    { s_w_id: Id.t;
      s_i_id: Id.t;
      s_qty: int32; 
      s_ytd: int32;
      s_order_cnt: int32
    }
  [@@deriving irmin]

  let merge
        {s_i_id; s_w_id; s_qty=q; 
         s_ytd=y; s_order_cnt=c; _}

        {s_qty=q1; s_ytd=y1; s_order_cnt=c1; _}

        {s_qty=q2; s_ytd=y2; s_order_cnt=c2; _} =

    let q' = SInt32.merge q q1 q2 in
    let y' = SInt32.merge y y1 y2 in
    let c' = SInt32.merge c c1 c2 in
    {s_i_id; s_w_id; s_qty=q'; s_ytd=y'; s_order_cnt=c'}

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module Customer = struct
  type t =
    { c_w_id: Id.t;
      c_d_id: Id.t;
      c_id: Id.t; 
      c_bal: int32; 
      c_ytd_payment: int32; 
      c_payment_cnt: int32; 
      c_delivery_cnt: int32
    }
  [@@deriving irmin]

  (* Due to delivery txn, customer merge is non-trivial. We shall do
   * real merging of customer at the DB level. Following is called
   * from the db level merge function.*)

  let merge
        {c_id; c_d_id; c_w_id; c_bal=b; 
         c_ytd_payment=y; c_payment_cnt=p;
         c_delivery_cnt=d; _} 

        {c_bal=b1; c_ytd_payment=y1; 
         c_payment_cnt=p1; c_delivery_cnt=d1; _}

        {c_bal=b2; c_ytd_payment=y2; 
         c_payment_cnt=p2; c_delivery_cnt=d2; _} =

    let b' = SInt32.merge b b1 b2 in
    let y' = SInt32.merge y y1 y2 in
    let p' = SInt32.merge p p1 p2 in
    let d' = SInt32.merge d d1 d2 in
    {c_id; c_d_id; c_w_id; c_bal=b'; c_ytd_payment=y';
     c_payment_cnt=p'; c_delivery_cnt=d'}

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module IdPair = struct 
  type t = Id.t * Id.t
  [@@deriving irmin]

  let t = let open Irmin.Type in pair id id

  let to_string : t -> string = 
    Fmt.to_to_string (Irmin.Type.pp_json t)

  let compare (x1,y1) (x2,y2) = 
    match Id.compare x1 x2, Id.compare y1 y2 with
      | 0, v2 -> v2
      | v1, _ -> v1
end

module IdTriple = struct
  type t = Id.t * (Id.t * Id.t)
  [@@deriving irmin]

  let t = let open Irmin.Type in pair id (pair id id)

  let to_string : t -> string =
    Fmt.to_to_string (Irmin.Type.pp_json t)

  let compare (x1,(y1,z1)) (x2,(y2,z2)) =
    match Id.compare x1 x2, Id.compare y1 y2, Id.compare z1 z2 with
      | 0, 0, v3 -> v3
      | 0, v2, _ -> v2
      | v1, _, _ -> v1
end

module IdQuad = struct
  type t = Id.t * (Id.t * (Id.t * Id.t))
  [@@deriving irmin]

  let t = let open Irmin.Type in pair id (pair id (pair id id))

  let to_string : t -> string =
    Fmt.to_to_string (Irmin.Type.pp_json t)

  let compare (w1,(x1,(y1,z1))) (w2,(x2,(y2,z2))) =
    match Id.compare w1 w2, Id.compare x1 x2,
          Id.compare y1 y2, Id.compare z1 z2 with
      | 0, 0, 0, v4 -> v4
      | 0, 0, v3, _ -> v3
      | 0, v2, _, _ -> v2
      | v1, _, _, _ -> v1
end

module IdQuin = struct
  type t = Id.t * (Id.t * ( Id.t * (Id.t * Id.t)))
  [@@deriving irmin]

  let t = let open Irmin.Type in
    (pair id (pair id (pair id (pair id id))))

  let to_string : t -> string =
    Fmt.to_to_string (Irmin.Type.pp_json t)

  let compare (u1,(w1,(x1,(y1,z1)))) (u2, (w2,(x2,(y2,z2)))) =
    match Id.compare u1 u2, Id.compare w1 w2, Id.compare x1 x2,
          Id.compare y1 y2, Id.compare z1 z2 with
      | 0, 0, 0, 0, v5 -> v5
      | 0, 0, 0, v4, _ -> v4
      | 0, 0, v3, _, _ -> v3
      | 0, v2, _, _, _ -> v2
      | v1, _, _, _, _ -> v1
end

module WarehouseTable = Mrbmap.Make(Id)(Warehouse)

module DistrictTable = Mrbmap.Make(IdPair)(District)

module OrderTable = Mrbmap.Make(IdTriple)(Order)

module NewOrderTable = Mrbmap.Make(IdTriple)(NewOrder)

module OrderLineTable = Mrbmap.Make(IdQuad)(OrderLine)

module ItemTable = Mrbmap.Make(Id)(Item)

module HistTable = Mrbmap.Make(IdQuin)(Hist)

module StockTable = Mrbmap.Make(IdPair)(Stock)

module CustomerTable = Mrbmap.Make(IdTriple)(Customer)

type db =
  { warehouse_table: WarehouseTable.t;
    district_table: DistrictTable.t;
    order_table: OrderTable.t;
    neworder_table: NewOrderTable.t;
    orderline_table: OrderLineTable.t;
    item_table: ItemTable.t;
    hist_table: HistTable.t;
    stock_table: StockTable.t;
    customer_table: CustomerTable.t
  }
[@@deriving irmin]

module Db = struct
  type t = db
  let t = db_t

  let merge lca v1 v2 =
    { warehouse_table = WarehouseTable.merge
                          lca.warehouse_table
                          v1.warehouse_table
                          v2.warehouse_table
    ; district_table = DistrictTable.merge
                          lca.district_table
                          v1.district_table
                          v2.district_table
    ; order_table = OrderTable.merge
                          lca.order_table
                          v1.order_table
                          v2.order_table
    ; neworder_table = NewOrderTable.merge
                          lca.neworder_table
                          v1.neworder_table
                          v2.neworder_table
    ; orderline_table = OrderLineTable.merge
                          lca.orderline_table
                          v1.orderline_table
                          v2.orderline_table
    ; item_table = ItemTable.merge
                          lca.item_table
                          v1.item_table
                          v2.item_table
    ; hist_table = HistTable.merge
                          lca.hist_table
                          v1.hist_table
                          v2.hist_table
    ; stock_table = StockTable.merge
                          lca.stock_table
                          v1.stock_table
                          v2.stock_table
    ; customer_table = CustomerTable.merge
                          lca.customer_table
                          v1.customer_table
                          v2.customer_table
    }

  type o = t
  let o_merge = merge
  let to_adt t = t
  let of_adt t = t
end

module Txn = struct
  type 'a t = db -> 'a * db

  let bind m f = fun db ->
    let (a,db') = m db in
    f a db'

  let return a = fun db -> (a,db)
end

module Insert = struct
  let order_table o db = 
    let open Order in
    let t = db.order_table in
    let t'= OrderTable.insert (o.o_w_id, (o.o_d_id, o.o_id)) o t in
        ((),{db with order_table=t'})

  let neworder_table no db = 
    let open NewOrder in
    let t = db.neworder_table in
    let t'= NewOrderTable.insert 
              (no.no_w_id, (no.no_d_id, no.no_o_id)) no t in
        ((),{db with neworder_table=t'})

  let orderline_table r db = 
    let open OrderLine in
    let t = db.orderline_table in
    let t' = OrderLineTable.insert
       (r.ol_w_id, (r.ol_d_id, (r.ol_o_id, r.ol_i_id))) r t in
    ((),{db with orderline_table=t'})

  let hist_table r db = 
    let open Hist in
    let t = db.hist_table in
    let t' = HistTable.insert
       (r.h_w_id, (r.h_d_id, (r.h_c_w_id, (r.h_c_d_id, r.h_c_id)))) r t in
    ((),{db with hist_table=t'})

  let item_table o db = 
    let open Item in
    let t = db.item_table in
    let t'= ItemTable.insert (o.i_id) o t in
        ((),{db with item_table=t'})

  let warehouse_table o db = 
    let open Warehouse in
    let t = db.warehouse_table in
    let t'= WarehouseTable.insert (o.w_id) o t in
        ((),{db with warehouse_table=t'})

  let district_table o db = 
    let open District in
    let t = db.district_table in
    let t'= DistrictTable.insert (o.d_w_id, o.d_id) o t in
        ((),{db with district_table=t'})

  let customer_table o db = 
    let open Customer in
    let t = db.customer_table in
    let t'= CustomerTable.insert (o.c_w_id, (o.c_d_id, o.c_id)) o t in
        ((),{db with customer_table=t'})

  let stock_table o db = 
    let open Stock in
    let t = db.stock_table in
    let t'= StockTable.insert (o.s_w_id, o.s_i_id) o t in
        ((),{db with stock_table=t'})
end

module Update = struct 
  let warehouse_table sigf updf db = 
    let t = db.warehouse_table in
    let t' = WarehouseTable.update sigf updf t in
    ((), {db with warehouse_table=t'})

  let district_table sigf updf db = 
    let t = db.district_table in
    let t' = DistrictTable.update sigf updf t in
    ((), {db with district_table=t'})

  let order_table sigf updf db = 
    let t = db.order_table in
    let t' = OrderTable.update sigf updf t in
    ((), {db with order_table=t'})

  let orderline_table sigf updf db = 
    let t = db.orderline_table in
    let t' = OrderLineTable.update sigf updf t in
    ((), {db with orderline_table=t'})

  let stock_table sigf updf db = 
    let t = db.stock_table in
    let t' = StockTable.update sigf updf t in
    ((), {db with stock_table=t'})

  let customer_table sigf updf db = 
    let t = db.customer_table in
    let t' = CustomerTable.update sigf updf t in
    ((), {db with customer_table=t'})
end

module Delete = struct
  let neworder_table (no_w_id, no_d_id, no_o_id) db =
    let t = db.neworder_table in
    let t' = NewOrderTable.remove (no_w_id, (no_d_id,no_o_id)) t in
    ((), {db with neworder_table=t'})
end

module Select1 = struct
  open Printf

  let warehouse_table x db =
    try
      let t = db.warehouse_table in
      let res = WarehouseTable.find x t in
      (res, db)
    with Not_found ->
      failwith @@ sprintf "Warehouse<%s> not found"
        (Id.to_string x)

  let district_table (x,y) db =
    try
      let t = db.district_table in
      let res = DistrictTable.find (x,y) t in
      (res, db)
    with Not_found ->
      failwith @@ sprintf "District<%s> not found"
        (IdPair.to_string (x,y))

  let item_table x db =
    try
      let t = db.item_table in
      let res = ItemTable.find x t in
      (res, db)
    with Not_found ->
      failwith @@ sprintf "Item<%s> not found"
        (Id.to_string x)

  let order_table (x,y,z) db =
    try
      let t = db.order_table in
      let res = OrderTable.find (x,(y,z)) t in
      (res, db)
    with Not_found ->
      failwith @@ sprintf "Order<%s> not found"
        (IdTriple.to_string (x,(y,z)))

  let stock_table (x,y) db =
    try
      let t = db.stock_table in
      let res = StockTable.find (x,y) t in
      (res, db)
    with Not_found ->
      failwith @@ sprintf "Stock<%s> not found"
        (IdPair.to_string (x,y))

  let customer_table (x,y,z) db =
    try
      let t = db.customer_table in
      let res = CustomerTable.find (x,(y,z)) t in
      (res, db)
    with Not_found ->
      failwith @@ sprintf "Customer<%s> not found"
        (IdTriple.to_string (x,(y,z)))
end

module Select = struct
  let warehouse_table sigf db =
    let t = db.warehouse_table in
    let res = WarehouseTable.select sigf t in
    (res, db)

  let district_table sigf db =
    let t = db.district_table in
    let res = DistrictTable.select sigf t in
    (res, db)

  let item_table sigf db =
    let t = db.item_table in
    let res = ItemTable.select sigf t in
    (res, db)

  let order_table sigf db =
    let t = db.order_table in
    let res = OrderTable.select sigf t in
    (res, db)

  let orderline_table sigf db =
    let t = db.orderline_table in
    let res = OrderLineTable.select sigf t in
    (res, db)

  let neworder_table sigf db =
    let t = db.neworder_table in
    let res = NewOrderTable.select sigf t in
    (res, db)

  let stock_table sigf db =
    let t = db.stock_table in
    let res = StockTable.select sigf t in
    (res, db)

  let customer_table sigf db =
    let t = db.customer_table in
    let res = CustomerTable.select sigf t in
    (res, db)

  let hist_table sigf db =
    let t = db.hist_table in
    let res = HistTable.select sigf t in
    (res, db)
end

module App = struct
  let (+) = Int32.add
  let (-) = Int32.add
  let ( * ) = Int32.mul
  let (>>=) = Txn.bind

  open Warehouse
  open District
  open Order
  open NewOrder
  open OrderLine
  open Item
  open Stock
  open Customer
  open Hist

  open Printf

  let dump_stock_keys db = 
    let fp = open_out "stock_keys.db" in
    let dump2 k _ = 
      fprintf fp "%s\n" @@ IdPair.to_string k in
    begin 
      fprintf fp "\n> Stock\n";
      StockTable.iter dump2 db.stock_table;
      close_out fp;
      printf "Dumped keys in stock_keys.db\n";
      ((),db)
    end

  let new_order_txn w_id d_id c_id (ireqs: item_req list) : unit Txn.t  =
    let _ = printf "new_order_txn\n" in
    let _ = flush_all () in
    let o_id = Random.int64 10000000000L in
    let ord = let open Order in
              {o_id=o_id; o_w_id=w_id; 
               o_d_id=d_id; o_c_id=c_id; 
               o_ol_cnt=Int32.of_int @@ List.length ireqs; 
               o_carrier_id =false} in
    let new_ord = let open NewOrder in
                  {no_o_id=o_id; no_w_id=w_id; no_d_id=d_id} in
    Insert.order_table ord >>= fun _ ->
    Insert.neworder_table new_ord >>= fun _ ->
    List.fold_left
      (fun pre ireq -> 
         pre>>= fun () ->
         (*dump_stock_keys >>= fun () ->*)
         Select1.stock_table (ireq._ol_supply_w_id, 
                              ireq._ol_i_id) >>= fun stk ->
         Select1.item_table ireq._ol_i_id >>= fun item ->
         let ol = {ol_o_id=o_id; ol_d_id=d_id; ol_w_id=w_id; 
                   ol_num=ireq._ol_num; ol_i_id=ireq._ol_i_id; 
                   ol_supply_w_id=ireq._ol_supply_w_id; 
                   ol_amt=item.i_price * ireq._ol_qty;
                   ol_qty=ireq._ol_qty; ol_delivery_d=None} in
         let s_qty = if Int32.compare stk.s_qty 
                         (ireq._ol_qty + 10l) >= 0
                     then stk.s_qty - ireq._ol_qty
                     else stk.s_qty - ireq._ol_qty + 91l in
         Update.stock_table 
             (fun stock_key -> IdPair.compare stock_key
                   (ireq._ol_supply_w_id, ireq._ol_i_id))
             (fun s -> 
                { s with
                  s_qty = s_qty;
                  s_ytd = stk.s_ytd + ireq._ol_qty; 
                  s_order_cnt = stk.s_order_cnt + 1l}) >>= fun () ->
          Insert.orderline_table ol) 
      (Txn.return ())
      ireqs

  let payment_txn w_id d_id c_id h_amt = 
    let _ = printf "payment_txn\n" in
    let _ = flush_all () in
    let d_w_id = w_id in
    let c_w_id = w_id in
    let c_d_id = d_id in
    Select1.warehouse_table (w_id) >>= fun _ ->
    Select1.district_table (d_w_id, d_id) >>= fun _ ->
    Select1.customer_table (c_w_id, c_d_id, c_id) >>= fun _ ->
    let h_item = {h_c_id = c_id; h_c_d_id = c_d_id; h_c_w_id = c_w_id; 
                  h_d_id = d_id; h_w_id = w_id; h_amt = h_amt} in
    Update.warehouse_table
        (fun wh_id -> Id.compare wh_id w_id)
        (fun wh -> {wh with w_ytd = wh.w_ytd + h_amt}) >>= fun () ->
    Update.district_table
      (fun dist_key -> 
         IdPair.compare dist_key (d_w_id,d_id))
      (fun dist -> {dist with 
                      d_ytd = dist.d_ytd + h_amt}) >>= fun () ->
    Update.customer_table
      (fun ckey -> IdTriple.compare ckey
                    (c_w_id, (c_d_id, c_id)))
      (fun c -> 
         {c with c_bal = c.c_bal - h_amt;
                 c_ytd_payment = c.c_ytd_payment + h_amt;
                 c_payment_cnt = c.c_payment_cnt + 1l}) >>= fun () ->
    Insert.hist_table h_item
  
  let delivery_txn w_id =
    let _ = printf "delivery_txn\n" in
    let _ = flush_all () in
    Select.district_table 
      (fun (dist_w_id,_) -> 
         Id.compare dist_w_id w_id) >>= fun dists ->
    List.fold_left 
      (fun pre d -> 
         pre >>= fun () ->
         Select.neworder_table
           (fun (no_w_id, (no_d_id,_)) -> 
              IdPair.compare 
                (no_w_id, no_d_id) (w_id, d.d_id)) >>= fun nords ->
         let nop = minf (fun no -> no.no_o_id) nords in
         match nop with 
           | Some no ->
             begin 
               (* delete the no entry *)
               Delete.neworder_table
                 (no.no_w_id, no.no_d_id, no.no_o_id) >>= fun () ->
               Select1.order_table (w_id, d.d_id, no.no_o_id) >>= fun o ->
               Update.order_table
                 (fun okey -> IdTriple.compare okey
                                 (w_id, (d.d_id, no.no_o_id))) 
                 (fun o -> {o with o_carrier_id = true}) >>= fun () ->
               Update.orderline_table
                 (fun (k_w_id, (k_d_id, (k_o_id, _))) -> 
                    IdTriple.compare (k_w_id, (k_d_id, k_o_id)) 
                            (o.o_w_id, (o.o_d_id, o.o_id)))
                 (fun ol -> 
                    {ol with ol_delivery_d = 
                               Some (Unix.time ())}) >>= fun () ->
               Select.orderline_table
                (fun (k_w_id, (k_d_id, (k_o_id, _))) -> 
                    IdTriple.compare (k_w_id, (k_d_id, k_o_id)) 
                            (o.o_w_id, (o.o_d_id, o.o_id))) >>= fun ols ->
               let amt = List.fold_left (fun acc ol -> 
                                          acc + ol.ol_amt) 0l ols in
               Update.customer_table
                (fun ckey -> IdTriple.compare ckey
                                (w_id, (d.d_id, o.o_c_id)))
                (fun c -> 
                   {c with c_bal = c.c_bal + amt;
                           c_delivery_cnt = c.c_delivery_cnt + 1l})
             end
           | None -> Txn.return ()) 
      (Txn.return ()) dists
end
