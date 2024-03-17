object JsonInjections {
  import io.circe.literal._

  def multilineJson = json"""{
    "name": "hello",
    "world": 3
  }"""

  def singleLineJson = json"{ \"oh\":\"no\", \"number\": 2 }"

}
