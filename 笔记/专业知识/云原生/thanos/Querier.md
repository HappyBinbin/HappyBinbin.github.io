比较有意思的是 thanos 的查询器，可以查询出降采样或者raw的指标数据；简单来讲，就是 thanos 的 querier 实现了 prometheus 的 storage 的 Querier 接口方法， 来自定义自己的查询和组合数据返回的方式；


