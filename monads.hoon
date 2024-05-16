:: This follows along with the following youtube video:
:: https://youtu.be/C2w45qRc3aU?feature=shared
:: "The Absolute Best Intro to Monads For Software Engineers"
:: by Studying with Alex
::
:: Urbit-native monadic patterns are woven in as they become accessible.
::
|%
:: Raw code
::
++  ex1
  |%
  ++  square
    |=  x=@ud
    ^-  @ud
    (mul x x)
  ::
  ++  add-one
    |=  x=@ud
    ^-  @ud
    (add x 1)
  ::
  ++  composed
    |=  x=@ud
    ^-  @ud
    (add-one (square x))
  --
:: Code with logging
::
++  ex2
  |%
  +$  number-with-logs
    $:  result=@ud
        logs=(list tape)
    ==
  ::
  ++  square
    |=  x=@ud
    ^-  number-with-logs
    :-  (mul x x)
    ~["Squared {<x>} to get {<(mul x x)>}."]
  ::
  ++  add-one
    |=  x=number-with-logs
    ^-  number-with-logs
    :-  (add result.x 1)
    (weld logs.x ~["Added 1 to {<result.x>} to get {<(add result.x 1)>}."])
  ::
  ++  composed
    |=  x=@ud
    ^-  number-with-logs
    (add-one (square x))
  --
:: Issues with ex1:
:: - Argument of type $number-with-logs is not assignable to parameter 
::   of type @ud.
:: - Argument of type @ud is not assignable to parameter 
::   of type $number-with-logs.
:: 
:: Wrap with logs
::
++  ex3
  |%
  +$  number-with-logs  number-with-logs:ex2
  ++  add-one           add-one:ex2
  ::
  ++  wrap-with-logs
    |=  x=@ud
    ^-  number-with-logs
    [x ~]
  ::
  ++  square
    |=  x=number-with-logs
    ^-  number-with-logs
    :-  (mul result.x result.x)
    (weld logs.x ~["Squared {<result.x>} to get {<(mul result.x result.x)>}."])
  ::
  ++  composed
    |=  x=@ud
    ^-  number-with-logs
    (add-one (square (square (wrap-with-logs x))))
  --
:: Run with logs
:: We'd actually prefer to accept a @ud instead of a number-with-logs...
::
++  ex4
  |%
  ++  number-with-logs  number-with-logs:ex2
  ++  wrap-with-logs    wrap-with-logs:ex3
  ++  square            square:ex2
  ::
  +$  transform  $-(@ud number-with-logs)
  ::
  ++  run-with-logs
    |=  [input=number-with-logs =transform]
    ^-  number-with-logs
    =/  new=number-with-logs  (transform result.input)
    :-  result.new
    (weld logs.input logs.new)
  ::
  ++  add-one
    |=  x=@ud
    ^-  number-with-logs
    :-  (add x 1)
    ~["Added 1 to {<x>} to get {<(add x 1)>}."]
  ::
  ++  composed
    |=  x=@ud
    ^-  number-with-logs
    =/  new=number-with-logs  (wrap-with-logs x)
    =.  new                   (run-with-logs new square)
    =.  new                   (run-with-logs new add-one)
    =.  new                   (run-with-logs new square)
    (run-with-logs new add-one)
  :: Instead of updating our number-with-logs by successively
  :: running the updated output through a new run-with-logs with a
  :: new transform, we can first transform the output and then
  :: pass it using run-with-logs to a transform to be specified later
  ::
  ++  apply-square
    |=  tan=transform
    ^-  transform
    |=  x=@ud
    (run-with-logs (square x) tan)
  ::
  ++  apply-add-one
    |=  tan=transform
    ^-  transform
    |=  x=@ud
    (run-with-logs (add-one x) tan)
  ::
  ++  alternate
    %-  apply-square
    %-  apply-add-one
    %-  apply-square
    add-one
  ::
  ++  alternate-rewritten
    |=  x=@ud
    ^-  number-with-logs
    %+  run-with-logs
      (square x)
    |=  x=@ud
    %+  run-with-logs
      (add-one x)
    |=  x=@ud
    %+  run-with-logs
      (square x)
    add-one
  :: This suggests the micgal pattern....
  :: (since the micgal bind expects a "bind-builder" which accepts a mmold
  :: we just use _run-with-logs here since (_run-with-logs any-mold)
  :: will just give us back run-with-logs)
  ::
  ++  micgal
    |=  x=@ud
    ^-  number-with-logs
    ;<  y=@ud  _run-with-logs  (square x)
    ;<  z=@ud  _run-with-logs  (add-one y)
    ;<  w=@ud  _run-with-logs  (square z)
    (add-one w)
  --
::
++  ex5
  =,  ex4
  |%
  +$  rwl-type  $-([number-with-logs transform] number-with-logs)
  ::
  ++  chain
    |=  [run-with-logs=rwl-type tans=(list transform)]
    ^-  transform
    ?~  tans  !!
    ?~  t.tans  i.tans
    =/  rest=transform  $(tans t.tans)
    |=  x=@ud
    =/  new=number-with-logs  (i.tans x)
    (run-with-logs (i.tans x) rest)
  ::
  ++  composed
    |=  x=@ud
    ^-  number-with-logs
    %.  x
    %+  chain
      run-with-logs
    :~  square
        add-one
        square
        add-one
    ==
  :: This suggests the micsig pattern....
  ::
  ++  micsig
    |=  x=@ud
    ^-  number-with-logs
    %.  x
    ;~  run-with-logs
      square
      add-one
      square
      add-one
    ==
  --
::
++  ex6
  |%
  ++  nums  `(map @ud @ud)`(my ~[[1 2] [2 3] [3 4] [4 5]])
  ++  get   |=(x=@ud `(unit @ud)`(~(get by nums) x))
  :: This is just +biff
  ::
  ++  run
    |=  [input=(unit @ud) transform=$-(@ud (unit @ud))]
    ^-  (unit @ud)
    ?~  input
      ~
    (transform u.input)
  ::
  ++  composed
    |=  x=@ud
    ^-  (unit @ud)
    =/  new=(unit @ud)  (some x)
    =.  new             (run new get)
    (run new get)
  ::
  ++  micsig
    |=  x=@ud
    ^-  (unit @ud)
    (;~(run get get) x)
  ::
  ++  micsig-biff
    |=  x=@ud
    ^-  (unit @ud)
    (;~(biff get get) x)
  --
:: generic logger
::
++  ex7
  |%
  ++  noun-with-logs
    |$  [item]
    $:  result=item
        logs=(list tape)
    ==
  ::
  ++  transform  
    |$  [item]
    $-(item (noun-with-logs item))
  ::
  ++  wrap-with-logs
    |*  =mold
    |=  x=mold
    ^-  (noun-with-logs mold)
    [x ~]
  ::
  ++  run-with-logs
    |*  =mold
    |=  [input=(noun-with-logs mold) =(transform mold)]
    ^-  (noun-with-logs mold)
    =/  new=(noun-with-logs mold)  (transform result.input)
    :-  result.new
    (weld logs.input logs.new)
  ::
  ++  square
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    :-  (mul x x)
    ~["Squared {<x>} to get {<(mul x x)>}."]
  ::
  ++  add-one
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    :-  (add x 1)
    ~["Added 1 to {<x>} to get {<(add x 1)>}."]
  ::
  ++  composed
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    %+  (run-with-logs @ud)
      (square x)
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    %+  (run-with-logs @ud)
      (add-one x)
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    %+  (run-with-logs @ud)
      (square x)
    add-one
  ::
  ++  micgal
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    ;<  y=@ud  run-with-logs  (square x)
    ;<  z=@ud  run-with-logs  (add-one y)
    ;<  w=@ud  run-with-logs  (square z)
    (add-one w)
  --
--