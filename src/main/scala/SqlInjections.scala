object Slick {
  import slick.sql._
  import slick.jdbc.H2Profile.api._

  sql"SELECT * FROM cart WHERE amount > 42"

  sql"""SELECT * FROM USER""".as[Int]
  sqlu"""UPDATE user SET name = 'John' and surname = 'Doe' """

  sql""" SELECT this FROM that"""
}

object Doobie {

  import doobie._
  import doobie.implicits._

  def query = sql"""SELECT * FROM user""".query[Int]
  def fragment = fr"""WHERE x = 42""" // adds a whitespace after for next potential fragment
  def fragment2 = fr0"""WHERE x = 33""" // looks like a no-op, no whitespace in the end
}
