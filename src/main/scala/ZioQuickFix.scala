import zio._
import cats.implicits._
import scala.util.Random

def x: ZIO[Any, Throwable, Int] = ZIO.succeed("42".toInt)
def someCond = Random.nextBoolean()
def duration = 1.second

// .unit
def unit1: ZIO[Any, Throwable, Unit] = x.map(_ => ())
def unit2: ZIO[Any, Throwable, Unit] = x *> ZIO.unit
def unit3: ZIO[Any, Throwable, Unit] = x.as(())
def unit4 = ZIO.attempt("42".toInt).map(_ => ())
def unit5: ZIO[Any, Throwable, Unit] = x *> ZIO.succeed(())

def unit6 = ZIO.succeed(42).map(_ => "string").map(_ => 42).tap(x => ZIO.logInfo("hello $x")).map(_ => ())

def unit7 = x *> ZIO.succeed(4233)

// .as("string")
def as: ZIO[Any, Throwable, String] = x.map(_ => "42")
def asNum = x.map(_ => 33)
def asBig = x.map { _ => ZIO.logInfo("hoi") *> ZIO.succeed(42) }

// .ignore
def ignore1: URIO[Any, Unit] = x.foldCause(_ => (), _ => ())
def ignore2 = ZIO.attempt("42".toInt).foldCause(_ => (), _ => ())
def ignore3 = ZIO.attempt("42".toInt).tap(x => ZIO.logInfo(x.toString)).foldCause(_ => (), _ => ())
def ignore4: URIO[Any, Unit] = x.unit.catchAll(_ => ZIO.unit)
def ignore5 = ZIO.attempt("42".toInt).unit.catchAll(_ => ZIO.unit)
def ignore6 = ZIO.attempt("42".toInt).catchAll(_ => ZIO.unit).unit
def ignore7 = ZIO.attempt("42".toInt).ignore.tap(x => ZIO.logInfo(x.toString))
def ignore8 = ZIO
  .attempt("42".toInt)
  .tapError(err => ZIO.logInfo(err.toString))
  .catchAll(_ => ZIO.unit)
  .unit

// when
def when = if (someCond) x else ZIO.unit // x.when(cond)
def when2 = if (someCond) {
  x
} else {
  ZIO.unit
}
def when4 = if (someCond) { x }
else ZIO.unit
def when3 = if (!someCond) ZIO.unit else x // x.when(cond)
def when5 = if someCond then x else ZIO.unit
def when6 = if !someCond then ZIO.unit else x

// unless
def unless = if (someCond) ZIO.unit else x // -> x.unless(someCond)
def unless2 = if (!someCond) x else ZIO.unit // -> x.unless(someCond)
def unless3 = if someCond then ZIO.unit else x // -> x.unless(someCond)
def unless4 = if !someCond then x else ZIO.unit // -> x.unless(someCond)

// zipLeft/zipRight
def a = ZIO.logInfo("log")
def zipleft = x.tap(_ => a) // x.zipLeft(a)
def zipLeft2 = x.tap(_ => a) // x <* a

def zipRight = x.flatMap(_ => a) // x.zipRight(a)
def zipRight2 = x.flatMap(_ => a) // x *> a

// exitCode (not-so-useful)
def exitCode = x.map(_ => ExitCode.success) // x.exitCode
def exitCode2 = x.as(ExitCode.success) // x.exitCode
def exitCode3 = x.fold(_ => ExitCode.failure, _ => ExitCode.success) // x.exitCode

// orElseFail
def orElseFail = x.mapError(_ => "error") // x.orElseFail("error")
def orElseFail2 = x.orElse(ZIO.fail(new Exception("error"))) // x.orElseFail(new Exception("error"))

// .mapBoth (difficult)
def mapBoth = x.map(_ => 33).mapError(_ => "error")
def mapBoth2 = x.mapError(_ => "error").map(_ => 33)
def mapBoth3 = x.map(_ => 33).orElseFail("error")
def mapBoth4 = x.as(33).mapError(_ => "error")
def mapBoth5 = x.as(33).orElseFail("error")
def mapBoth6 = x.as(33).tap(r => ZIO.logInfo(r.toString)).mapError(_ => "error")

// delay
def delay = ZIO.sleep(duration) *> Console.printLine("...") // Console.printLine("...").delay(duration)
def delay2 = ZIO.sleep(duration).flatMap(_ => Console.printLine("...")) // Console.printLine("...").delay(duration)
