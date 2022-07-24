# POM 文件配置

## 总工程下的 POM 配置

```xml
<properties>
    <!-- Base -->
    <jdk.version>1.8</jdk.version>
    <sourceEncoding>UTF-8</sourceEncoding>
</properties>

<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>2.3.5.RELEASE</version>
    <relativePath/> <!-- lookup parent from repository -->
</parent>
```

相对于工程下其他的模块来说，总POM就是这些模块的父类模块，在父类模块中一般只提供基础的定义，不提供各个Jar包的引入配置。如果在父类 POM 中引入了所有的 Jar，那么各个模块无论是否需要这个 Jar 都会被自动引入进去，造成没必要的配置，也会影响对核心Jar的扰乱，让你分不清自己需要的是否就在眼前。

## 模块类 POM 配置

```xml
<parent>
    <artifactId>lottery_happy</artifactId>
    <groupId>cn.happy</groupId>
    <version>1.0-SNAPSHOT</version>
</parent>

<packing>jar</packing>

<dependencies>
    <dependency>
        <groupId>cn.happy</groupId>
        <artifactId>lottery-common</artifactId>
        <version>1.0-SNAPSHOT</version>
    </dependency>
</dependencies>

<build>
    <finalName>lottry-rpc</finalName> <!-- 定义了编译、打包、部署的项目名称 -->
    <plugins>
        <!-- 编译plugin -->
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compile-plugin</artifactId>
            <configuration>
                <source>${jdk.version}</source>
                <target>${jdk.version}</target>
                <compileVersion>1.8</compileVersion>
            </configuration>
        </plugin>
    </plugins>
</build>

```

在各个模块配置中需要关注的点包括：

- 依赖父POM配置 `parent`
- 构建包类型 `packing`
- 需要引入的包 `dependencies`
- 构建信息 `build`

因为有些时候在这个模块工程下还可能会有一些差异化信息的引入

## pom 中标签 < plugins > 和 < pluginManagement >的区别

pluginmanagement标签一般用在父pom中，子元素可以包含**plugins**插件，比如

```xml
<pluginManagement>
    <plugins>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-source-plugin</artifactId>
            <version>2.1</version>
            <configuration>
                <attach>true</attach>
            </configuration>
            <executions>
                <execution>
                    <phase>compile</phase>
                    <goals>
                        <goal>jar</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</pluginManagement>
```

然后，在子pom文件中就可以这样使用：

```xml
<plugins>
    <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-source-plugin</artifactId>
    </plugin>
</plugins>
```


省去了版本、配置等信息，只需指定groupId和artifactId即可。

但是在父pom中，如果使用这个标签来包裹plugins插件，当在此项目根目录运行对应的mvn命令时，如果在子pom中没有直接像上面再次引用这个plugin，那么不会触发这个plugin插件，只有在子pom中再次引用了之后，才会在对应的子项目路径下触发这个plugin.

plugins和pluginManagement标签都需要在build标签中。

## War包 POM 配置

```xml
<artifactId>lottery-interfaces</artifactId>

<!-- 打包方式，构建 war 包 -->
<packaging>war</packaging>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    ...
</dependencies>

<build>
    <finalName>Lottery</finalName>
    <resources>
        <resource>
            <directory>src/main/resources</directory>
            <filtering>true</filtering>
            <includes>
                <include>**/**</include>
            </includes>
        </resource>
    </resources>
    <testResources>
        <testResource>
            <directory>src/test/resources</directory>
            <filtering>true</filtering>
            <includes>
                <include>**/**</include>
            </includes>
        </testResource>
    </testResources>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
        </plugin>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <configuration>
                <source>8</source>
                <target>8</target>
            </configuration>
        </plugin>
    </plugins>
</build>
```

- lottery-interfaces 是整个程序的出口，也是用于构建 War 包的工程模块，所以你会看到一个 `<packaging>war</packaging>` 的配置。
- 在 dependencies 会包含所有需要用到的 SpringBoot 配置，也会包括对其他各个模块的引入。
- 在 build 构建配置上还会看到一些关于测试包的处理，比如这里包括了资源的引入也可以包括构建时候跳过测试包的配置。































