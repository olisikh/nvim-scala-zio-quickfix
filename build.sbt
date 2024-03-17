val scala3Version = "3.4.0"

lazy val root = project
  .in(file("."))
  .settings(
    name := "scala",
    version := "0.1.0-SNAPSHOT",
    scalaVersion := scala3Version,
    libraryDependencies ++= Seq(
      "dev.zio" %% "zio" % "2.0.21",
      "org.typelevel" %% "cats-core" % "2.10.0",
      "com.typesafe.slick" %% "slick" % "3.5.0",
      "org.tpolecat" %% "doobie-core" % "0.13.4",
      "io.circe" %% "circe-literal" % "0.14.6",
      "org.scalameta" %% "munit" % "0.7.29" % Test
    )
  )
