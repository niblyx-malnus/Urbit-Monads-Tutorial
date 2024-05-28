:: This follows along with the following youtube video:
:: https://youtu.be/C2w45qRc3aU
:: "The Absolute Best Intro to Monads For Software Engineers"
:: by Studying with Alex
::
:: Urbit-native monadic patterns are woven in as they become accessible.
::
:: Referring to https://docs.urbit.org/language/hoon/reference/rune/mic
:: for ;~ and ;< will also be helpful.
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
  :: (since the micgal bind expects a "bind-builder" which accepts a mold
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
  ::
  ++  log
    |*  [x=* =tape]
    ^-  (noun-with-logs _x)
    [x ~[tape]]
  ::
  ++  just-square   |=(x=@ud `@ud`(mul x x))
  ++  just-add-one  |=(x=@ud `@ud`(add x 1))
  ::
  ++  micgal-log
    |=  x=@ud
    ^-  (noun-with-logs @ud)
    ;<  y=@ud  run-with-logs  (log (just-square x) "Squaring...")
    ;<  z=@ud  run-with-logs  (log (just-add-one y) "Adding one...")
    ;<  w=@ud  run-with-logs  (log (just-square z) "Squaring again...")
    (log (just-add-one w) "Adding one and ending.")
  --
:: The list monad
::
++  ex8
  |%
  ::  flat-map
  ::
  ++  run
    |*  =mold
    |=  [input=(list mold) transform=$-(mold (list mold))]
    ^-  (list mold)
    ?~  input
      ~
    %+  weld
      (transform i.input)
    $(input t.input)
  ::
  ++  en-list
    |=  x=@t
    ^-  (list @t)
    [x ~]
  :: door example from video
  ::
  ++  en-door
    |=  x=@t
    ^-  (list @t)
    :~  (rap 3 x ?~(x '' ' ') 'red' ~)
        (rap 3 x ?~(x '' ' ') 'green' ~)
        (rap 3 x ?~(x '' ' ') 'blue' ~)
    ==
  ++  en-coin
    |=  x=@t
    ^-  (list @t)
    :~  (rap 3 x ?~(x '' ' ') 'heads' ~)
        (rap 3 x ?~(x '' ' ') 'tails' ~)
    ==
  ::
  ++  composed
    |=  x=@t
    ^-  (list @t)
    =/  new=(list @t)  (en-list x)
    =.  new            ((run @t) new en-coin)
    =.  new            ((run @t) new en-door)
    ((run @t) new en-coin)
  ::
  ++  micsig          ;~((run @t) en-coin en-door en-coin)
  ++  micsig-on-list  (curr (run @t) micsig)
  ::
  ++  apply-en-door
    |=  tan=$-(@t (list @t))
    ^-  $-(@t (list @t))
    |=  x=@t
    ((run @t) (en-door x) tan)
  ::
  ++  apply-en-coin
    |=  tan=$-(@t (list @t))
    ^-  $-(@t (list @t))
    |=  x=@t
    ((run @t) (en-coin x) tan)
  ::
  ++  alternate
    %-  apply-en-coin
    %-  apply-en-door
    en-coin
  ::
  ++  alternate-rewritten
    |=  x=@t
    ^-  (list @t)
    %+  (run @t)
      (en-coin x)
    |=  x=@t
    %+  (run @t)
      (en-door x)
    en-coin
  ::
  ++  micgal
    |=  x=@t
    ^-  (list @t)
    ;<  y=@t  run  (en-coin x)
    ;<  z=@t  run  (en-door y)
    (en-coin z)
  ::
  ++  micgal-on-list  (curr (run @t) micgal)
  ::
  ++  micgal-2
    |=  x=@t
    ^-  (list @t)
    ;<  y=@t    run  (en-coin x)
    :: for each y, instead of using y
    :: we re-use x; try it out to see the effect
    ::
    ;<  z=@t  run  (en-door x)
    (en-coin z)
  ::
  ++  flat-map  run
  ::
  ++  ud-example
    ((flat-map @ud) ~[0 1 2 3] |=(x=@ud (turn (gulf 0 x) (cury mul 2))))
  --
:: The either monad
::
++  ex9
  |%
  ++  run
    |*  [a=mold b=mold]
    |=  [input=(each a tang) transform=$-(a (each b tang))]
    ^-  (each b tang)
    ?-  -.input
      %|  input
      %&  (transform p.input)
    ==
  ::
  ++  en-each
    |*  =mold
    |=  a=mold
    ^-  (each mold tang)
    [%& a]
  ::
  ++  div-1000
    |=  x=@ud
    ^-  (each @ud tang)
    ?:  =(0 x)
      [%| leaf+"divide-by-zero" ~]
    [%& (div 1.000 x)]
  ::
  ++  sub-100
    |=  x=@ud
    ^-  (each @ud tang)
    ?:  (lte x 100)
      [%| leaf+"subtract-underflow" ~]
    [%& (sub x 100)]
  ::
  ++  en-odd-tape
    |=  x=@ud
    ^-  (each tape tang)
    ?:  =(0 (mod x 2))
      [%| leaf+"even-number" ~]
    [%& (scow %ud x)]
  :: will only go all the way through for 3
  ::
  ++  composed
    |=  x=@ud
    ^-  (each tape tang)
    =/  new=(each @ud tang)  ((en-each @ud) x)
    =.  new                  ((run @ud @ud) new div-1000)
    =.  new                  ((run @ud @ud) new sub-100)
    ((run @ud tape) new en-odd-tape)
  :: We can't only write a micsig since our bind function switches part way.
  ::
  ++  micsig
    |=  x=@ud
    ^-  (each tape tang)
    %+  (run @ud tape)
      (;~((run @ud @ud) div-1000 sub-100) x)
    en-odd-tape
  ::
  ++  apply-div-1000
    |*  =mold
    |=  tan=$-(@ud (each mold tang))
    |=  x=@ud
    ((run @ud mold) (div-1000 x) tan)
  ::
  ++  apply-sub-100
    |*  =mold
    |=  tan=$-(@ud (each mold tang))
    |=  x=@ud
    ((run @ud mold) (sub-100 x) tan)
  ::
  ++  apply-en-odd-tape
    |*  =mold
    |=  tan=$-(tape (each mold tang))
    |=  x=tape
    ((run tape mold) (en-odd-tape x) tan)
  ::
  ++  alternate
    %-  (apply-div-1000 tape)
    %-  (apply-sub-100 tape)
    en-odd-tape
  ::
  ++  alternate-rewritten
    |=  x=@ud
    ^-  (each tape tang)
    %+  (run @ud tape)
      (div-1000 x)
    |=  x=@ud
    %+  (run @ud tape)
      (sub-100 x)
    en-odd-tape
  ::
  ++  micgal
    |=  x=@ud
    ^-  (each tape tang)
    ;<  y=@ud  (curr run tape)  (div-1000 x)
    ;<  z=@ud  (curr run tape)  (sub-100 y)
    ;<  =tape  (curr run tape)  (en-odd-tape z)
    [%& tape]
  ::
  ++  micgal-mule
    |=  x=@ud
    ^-  (each tape tang)
    ;<  y=@ud  (curr run tape)  (mule |.((div 1.000 x)))
    ;<  z=@ud  (curr run tape)  (mule |.((sub y 100)))
    ;<  =tape  (curr run tape)  (en-odd-tape z)
    [%& tape]
  --
::
++  common-monads
  |%
  :: State monad
  :: Pass along a piece of state that is being mutated
  :: Not useful on urbit (use abet/abed engine core pattern etc.)
  ::
  ++  mutation
    |*  [state=mold value=mold]
    =<  form
    |%
    ++  raw-form
      |$  [state value]
      $-(state [state value])
    ::
    ++  form  (raw-form state value)
    ::
    ++  pure
      |=  v=value
      ^-  form
      |=(s=state [s v])
    ::
    ++  bind
      |*  x=mold
      |=  $:  mutation-x=(raw-form state x)
              transform=$-(x form)
          ==
      ^-  form
      |=  old=state
      ^-  [state value]
      =/  [new=state val=x]  (mutation-x old)
      ((transform val) new)
    ::
    ++  just-value
      |=  [=state mutation=form]
      ^-  value
      (tail (mutation state))
    ::
    ++  just-state
      |=  [=state mutation=form]
      ^+  state
      (head (mutation state))
    --
  :: Reader monad
  :: Pass along a read-only piece of state
  ::
  ++  reader
    |*  [env=mold val=mold]
    =<  form
    |%
    ++  raw-form
      |$  [env val]
      $-(env val)
    ::
    ++  form  (raw-form env val)
    ::
    ++  pure
      |=  v=val
      ^-  (reader env val)
      |=(e=env v)
    ::
    ++  bind
      |*  x=mold
      |=  [reader-x=(raw-form env x) transform=$-(x form)]
      ^-  form :: (reader env val)
      |=  =env
      =/  val=x  (reader-x env)
      ((transform val) env)
    --
  :: Writer monad ("wrap/run with logs")
  ::
  ++  writer
    |*  [log=mold value=mold]
    =<  form
    |%
    ++  raw-form
      |$  [log value]
      [logs=(list log) =value]
    ++  form  (raw-form log value)
    ++  pure  |=(v=value [~ v])
    ++  bind
      |*  x=mold
      |=  [writer-x=(raw-form log x) transform=$-(x form)]
      ^-  form :: (writer log value)
      =/  new=form  (transform value.writer-x)
      [(weld logs.writer-x logs.new) value.new]
    --
  :: Maybe monad (exception)
  ::
  ++  maybe
    |*  value=mold
    |%
    ++  form  (unit value)
    ++  pure  |=(v=value [~ v])
    ++  bind
      |*  x=mold
      |=  [unit-x=(unit x) transform=$-(x form)]
      ^-  form :: (unit value)
      ?~  unit-x
        ~
      (transform u.unit-x)
    --
  :: List monad
  ::
  ++  branch
    |*  item=mold
    |%
    ++  form   (list item)
    ++  pure   |=(i=item [i ~])
    ++  bind
      |*  x=mold
      |=  [list-x=(list x) transform=$-(x form)]
      ^-  form :: (list item)
      ?~  list-x
        ~
      %+  weld
        (transform i.list-x)
      $(list-x t.list-x)
    --
  --
--
