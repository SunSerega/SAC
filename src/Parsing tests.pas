uses ExprParser;

begin
  var e := Expr.FromString('"a"+("b"*n1)');
  
  var nd := new Dictionary<string, real>;
  nd.Add('n1', 500);
  
  var sd := new Dictionary<string, string>;
  sd.Add('s1', 'abc|');
  
  var od := new Dictionary<string, object>;
  od.Add('o1', nil);
  
  var oe := OptExprWrapper.FromExpr(e, nd.Keys.ToList, sd.Keys.ToList, od.Keys.ToList);
  var res := oe.Calc(nd, sd, od);
  writeln(res);
end.