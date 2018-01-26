#!/usr/bin/env bash
base=$(cd $(dirname $0);pwd)


__cmd__() {
	if which ${1:-"cmd"} >/dev/null 2>&1;then echo 1;else echo 0;fi
}

__get__() {
	local i=$1
	test "x$i" == "x" && read -p "Please enter $2: " -t 30 i
	test "x$i" == "x" && { echo "0x0F";return; }
	echo $i
}
__exit__() {
	test "x$1" == "x0x0F" && { echo "parameter error.">&2;exit; }
}

create_module() {
	local module=$(__get__ "$1" "module name")
	__exit__ "$module"
	local src_dir=src/main/scala
	local code_dir=$src_dir/${group_id//./\/}
	local deploy_dir=deploy
	local conf_dir=$deploy_dir/conf/online

	mkdir -p $name/$module
	test ! -d $name/$module && { echo "create modulue dir failed.">&2;exit; }

	mkdir -p $name/$module/$code_dir
	mkdir -p $name/$module/${src_dir/main/test}
	mkdir -p $name/$module/$conf_dir

	cp $name/default.properties $name/$module/$conf_dir/${module}.properties

	echo "# $module 模块说明文档" >$name/$module/README.md
	cat > $name/$module/assembly.xml <<EOF
<assembly>
    <id>bin</id>
    <formats>
        <format>tar.gz</format>
    </formats>
    <dependencySets>
        <dependencySet>
            <useProjectArtifact>true</useProjectArtifact>
            <outputDirectory>lib</outputDirectory>
            <useProjectAttachments>true</useProjectAttachments>
            <includes>
                <include>org.fire.spark.streaming:fire-spark</include>
            </includes>
        </dependencySet>
        <dependencySet>
            <!--
               不使用项目的artifact，第三方jar不要解压
            -->
            <useProjectArtifact>false</useProjectArtifact>
            <outputDirectory>lib</outputDirectory>
            <useProjectAttachments>true</useProjectAttachments>
            <scope>provided</scope>
        </dependencySet>
    </dependencySets>
    <fileSets>
        <fileSet>
            <outputDirectory>/</outputDirectory>
            <includes>
                <include>README.md</include>
                <include>../run.sh</include>
            </includes>
        </fileSet>
        <fileSet>
            <directory>\${project.basedir}/deploy</directory>
            <outputDirectory>/</outputDirectory>
        </fileSet>
        <!-- 把项目自己编译出来的jar文件，打包进gz文件的lib目录 -->
        <fileSet>
            <directory>\${project.build.directory}</directory>
            <outputDirectory>lib</outputDirectory>
            <includes>
                <include>*.jar</include>
            </includes>
        </fileSet>
    </fileSets>
</assembly>
EOF

	cat >$name/$module/pom.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <artifactId>$artifact_id</artifactId>
        <groupId>$group_id</groupId>
        <version>$version</version>
		<relativePath>../pom.xml</relativePath>
    </parent>
    <modelVersion>4.0.0</modelVersion>

    <artifactId>$module</artifactId>

    <dependencies>
        <dependency>
            <groupId>org.fire.spark.streaming</groupId>
            <artifactId>fire-spark</artifactId>
        </dependency>
    </dependencies>


    <build>
        <plugins>
            <plugin>
                <artifactId>maven-assembly-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>

EOF

}

create_pom() {
	local group_id=$(__get__ "$1" "group id")
	__exit__ "$group_id"
	local artifact_id=$(__get__ "$2" "artifact id")
	__exit__ "$artifact_id"
	local module=$(__get__ "$3" "module name")
	__exit__ "$module"
	local version=$(__get__ "${4:-"1.0"}" "version")
	__exit__ "$version"

cat > $name/pom.xml <<EOF

<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>$group_id</groupId>
    <artifactId>$artifact_id</artifactId>
    <packaging>pom</packaging>
    <version>$version</version>

    <profiles>
        <profile>
            <!--
            mvn clean package
            直接打包，只会将 assembly.xml 文件中
            <includes>
                <include>org.fire.spark.streaming:fire-spark</include>
            </includes>
            包含的Jar包打包进去
             -->
            <id>default</id>
            <properties>
                <scope>compile</scope>
            </properties>
            <activation>
                <activeByDefault>true</activeByDefault>
            </activation>
        </profile>
        <profile>
            <!--
             mvn clean package -Pwithjar -Dmaven.test.skip=true
            包含依赖jar打包，会将assembly.xml 文件中
            <includes>
                <include>org.fire.spark.streaming:fire-spark</include>
            </includes>
            包含的Jar和pom中设置 <scope>\${project.scope}</scope> 的jar一起打包进去，
            这样蹩脚的设计，主要是因为我不知道怎么能优雅的把 运行、编译都依赖的JarA 抽离出来
             -->
            <id>withjar</id>
            <properties>
                <scope>provided</scope>
            </properties>
        </profile>
    </profiles>
    <modules>
        <module>$module</module>
    </modules>

    <!-- 定义统一版本号-->
    <properties>
        <fire.spark.version>2.2.0_kafka-0.10</fire.spark.version>

        <spark.version>2.2.0</spark.version>
        <hadoop.version>2.6.0</hadoop.version>
        <hbase.version>1.2.0-cdh5.12.1</hbase.version>
        <hive.version>1.1.0-cdh5.12.1</hive.version>

        <scala.version>2.11.12</scala.version>
        <scala.binary.version>2.11</scala.binary.version>
        <redis.version>2.8.2</redis.version>
        <mysql.version>5.1.6</mysql.version>
        <kafka.version>0.10.2.0</kafka.version>
        <es.version>5.6.3</es.version>
        <protobuf.version>2.5.0</protobuf.version>

        <log4j.version>1.7.25</log4j.version>
        <json4s.version>3.2.10</json4s.version>
        <spray.version>1.3.3</spray.version>
        <akka.version>2.3.9</akka.version>

        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <project.build.jdk>1.8</project.build.jdk>


        <PermGen>64m</PermGen>
        <MaxPermGen>512m</MaxPermGen>
        <CodeCacheSize>512m</CodeCacheSize>

    </properties>


    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.fire.spark.streaming</groupId>
                <artifactId>fire-spark</artifactId>
                <version>\${fire.spark.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>


    <build>
        <sourceDirectory>src/main/scala</sourceDirectory>

        <resources>
            <resource>
                <directory>src/main/resources</directory>
            </resource>
        </resources>

        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.7.0</version>
                <configuration>
                    <source>\${project.build.jdk}</source>
                    <target>\${project.build.jdk}</target>
                </configuration>
            </plugin>

            <plugin>
                <groupId>net.alchim31.maven</groupId>
                <artifactId>scala-maven-plugin</artifactId>
                <version>3.2.2</version>
                <executions>
                    <execution>
                        <id>compile-scala</id>
                        <phase>compile</phase>
                        <goals>
                            <goal>add-source</goal>
                            <goal>compile</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>test-compile-scala</id>
                        <phase>test-compile</phase>
                        <goals>
                            <goal>add-source</goal>
                            <goal>testCompile</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <scalaVersion>\${scala.version}</scalaVersion>
                </configuration>
            </plugin>
        </plugins>

        <pluginManagement>
            <plugins>
                <plugin>
                    <artifactId>maven-assembly-plugin</artifactId>
                    <version>3.0.0</version>
                    <executions>
                        <execution>
                            <id>distro-assembly</id>
                            <phase>package</phase>
                            <goals>
                                <goal>single</goal>
                            </goals>
                        </execution>
                    </executions>
                    <configuration>
                        <appendAssemblyId>false</appendAssemblyId>
                        <descriptors>
                            <descriptor>assembly.xml</descriptor>
                        </descriptors>
                    </configuration>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>

</project>

EOF
	create_module "$module"
}
create_git_filter() {
	echo -e "# Created by .ignore support plugin (hsz.mobi)\n.idea/\n*.iml\ntarget/\n.DS_Store" >$name/.gitignore
}
create_readme() {
	echo -e "# $name 项目说明" >$name/README.md
}
create_default_conf() {
	cp $base/run.sh $name
	cp $base/create_default_conf.sh $name
	bash $base/create_default_conf.sh > $name/default.properties
}


create_project() {
	local name=$1
	test "x$name" == "x" && read -p "Please enter number: " -t 30 name
	test "x$name" == "x" && { echo "The name of the project can not be empty" >&2;exit; }
	mkdir -p $name
	test ! -d $name && { echo "project create failed." >&2;exit; }
	create_git_filter
	create_readme
	create_default_conf
	create_pom "$2" "$3" "$4" "$5"
	echo "procject $name create successful."
}

create_project "$@"
