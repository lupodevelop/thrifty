import gleeunit
import gleeunit/should
import thrifty/message.{Call, Exception, MessageHeader, Oneway, Reply}

pub fn main() {
  gleeunit.main()
}

// Message header encode/decode roundtrip tests

pub fn message_call_roundtrip_test() {
  let header =
    MessageHeader(name: "testMethod", message_type: Call, sequence_id: 123)
  let encoded = message.encode_message_header(header)
  let assert Ok(#(decoded, _)) = message.decode_message_header(encoded, 0)

  decoded.name |> should.equal("testMethod")
  decoded.message_type |> should.equal(Call)
  decoded.sequence_id |> should.equal(123)
}

pub fn message_reply_roundtrip_test() {
  let header =
    MessageHeader(name: "responseMethod", message_type: Reply, sequence_id: 456)
  let encoded = message.encode_message_header(header)
  let assert Ok(#(decoded, _)) = message.decode_message_header(encoded, 0)

  decoded.name |> should.equal("responseMethod")
  decoded.message_type |> should.equal(Reply)
  decoded.sequence_id |> should.equal(456)
}

pub fn message_exception_roundtrip_test() {
  let header =
    MessageHeader(
      name: "errorMethod",
      message_type: Exception,
      sequence_id: 789,
    )
  let encoded = message.encode_message_header(header)
  let assert Ok(#(decoded, _)) = message.decode_message_header(encoded, 0)

  decoded.name |> should.equal("errorMethod")
  decoded.message_type |> should.equal(Exception)
  decoded.sequence_id |> should.equal(789)
}

pub fn message_oneway_roundtrip_test() {
  let header =
    MessageHeader(name: "notifyMethod", message_type: Oneway, sequence_id: 0)
  let encoded = message.encode_message_header(header)
  let assert Ok(#(decoded, _)) = message.decode_message_header(encoded, 0)

  decoded.name |> should.equal("notifyMethod")
  decoded.message_type |> should.equal(Oneway)
  decoded.sequence_id |> should.equal(0)
}

pub fn message_empty_name_test() {
  let header = MessageHeader(name: "", message_type: Call, sequence_id: 1)
  let encoded = message.encode_message_header(header)
  let assert Ok(#(decoded, _)) = message.decode_message_header(encoded, 0)

  decoded.name |> should.equal("")
  decoded.message_type |> should.equal(Call)
  decoded.sequence_id |> should.equal(1)
}

pub fn message_long_name_test() {
  let long_name = "thisIsAVeryLongMethodNameThatExceedsTypicalLengths"
  let header =
    MessageHeader(name: long_name, message_type: Reply, sequence_id: 999)
  let encoded = message.encode_message_header(header)
  let assert Ok(#(decoded, _)) = message.decode_message_header(encoded, 0)

  decoded.name |> should.equal(long_name)
  decoded.message_type |> should.equal(Reply)
  decoded.sequence_id |> should.equal(999)
}
