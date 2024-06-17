## 前言

在k8s中，一切皆为资源，所有的CRUD操作，对象都是资源；引入schem就是为了更好地管理资源；

所以有必要先提前认识一下k8s里面的资源与如何管理资源

## Reference

1. https://www.cnblogs.com/xingzheanan/p/17771090.html

## 核心问题

1、k8s 对于资源的操作都是通过 Restful API 进行的，k8s中的路由是怎么注册的？

2、apiserver服务是怎么启动的？

3、架构是如何设计的？数据结构之间的关联？

4、如何与数据库进行交互？

## Resource

k8s 里面的资源基本可以根据 API PATH 分为两个维度，以namespace、是否核心资源区分

- namespace
  - 带有 /namespace 路由，认为是某个 ns 下的资源
    - Pod 、Service、Deployment ...
  - 不带 /namepsace 路由，认为是 k8s cluster 的资源
    - Node、Persistent Volumn ...
- 是否核心资源
  - 核心资源，带有 /api/ 路由前缀
    - Pod、Service、Node ...
  - 拓展资源，带有 /apis/ 路由前缀
    - Deployment、StatefulSet ...

## Scheme

官方的定义：

`Scheme defines methods for serializing and deserializing API objects, a type registry for converting group, version, and kind information to and from Go schemas, and mappings between Go schemas of different versions. A scheme is the foundation for a versioned API and versioned configuration over time.`

一个Scheme包含了什么：

```go
// NewScheme creates a new Scheme. This scheme is pluggable by default.
func NewScheme() *Scheme {
	s := &Scheme{
		gvkToType:                 map[schema.GroupVersionKind]reflect.Type{},
		typeToGVK:                 map[reflect.Type][]schema.GroupVersionKind{},
		unversionedTypes:          map[reflect.Type]schema.GroupVersionKind{},
		unversionedKinds:          map[string]reflect.Type{},
		fieldLabelConversionFuncs: map[schema.GroupVersionKind]FieldLabelConversionFunc{},
		defaulterFuncs:            map[reflect.Type]func(interface{}){},
		versionPriority:           map[string][]string{},
		schemeName:                naming.GetNameFromCallsite(internalPackages...),
	}
	s.converter = conversion.NewConverter(s.nameFunc)
	// ...
	return s
}
```

变量说明：

- gvkToType：GroupVersionKind / reflect.Type  ，组别/版本/资源种类 => 资源类型
  - GVK 时什么，K8s中的资源很多，因此需要分组、分类管理，并兼容多个版本，因此存在GVK的定义
- typeToGVK，reflect.Type / GroupVersionKind，资源种类 => GVK
- unversionTypes：无版本资源类型与 GVK 的映射关系
- unversionKinds：资源种类与 资源类型的映射关系

可能又存在疑问：

- 资源种类是什么？
  - 例如：Deployment、Pod、StatefulSet等，都属于资源类型
- 资源类型是什么？
  - 将对象进行反射后的类型，是go的一种类型表示，K8s里面可以理解为 go struct 类型

上述这些变量的作用是什么？













