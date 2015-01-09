defmodule Wire.Decoder do

  @doc ~S"""
  Parses a binary containing 0 or more messages and
  returns a list with messages and the unparsed part of the message

  """
  @spec decode_messages(binary) :: {List.Keyword.t, binary}
  def decode_messages(binary) do
    << l :: 32-integer-big-unsigned, rest :: binary >> = binary
    cond do
      byte_size(rest) < l ->
        {[], binary}
      true ->
        decode_messages(binary, [])
    end
  end

  def decode_messages(s, acc) do
    << l :: 32-integer-big-unsigned, rest :: binary >> = s
    if byte_size(rest) < l do
      { acc, s }
    else
      { message, rest } = decode_message(s)
      if byte_size(rest) > 0 do
        decode_messages(rest, acc ++ [message])
      else
        { acc ++ [message], rest }
      end
    end
  end

  def decode_message(message) do
      << len :: 32-integer-big-unsigned,
        rest :: binary >> = message

      if len == 0 do
        {[type: :keep_alive], rest}
      else
        << id, rest :: binary >> = rest

        decode_message_type(len, id, rest)
      end
  end

  def decode_message_type(_len, id, rest) when id == 9 do
    << port :: 16-integer-big-unsigned, rest :: binary >> = rest
    {[type: :port, listen_port: port], rest}
  end

  def decode_message_type(len, id, rest) when id == 7 do
    block_length = len - 9
    << index :: 32-integer-big-unsigned,
       begin :: 32-integer-big-unsigned,
       block :: binary-size(block_length),
       rest  :: binary >> = rest
    {[type: :piece, index: index, begin: begin, block: block], rest}
  end

  def decode_message_type(_len, id, rest) when id in [8, 6] do
    << index   :: 32-integer-big-unsigned,
       begin   :: 32-integer-big-unsigned,
       length  :: 32-integer-big-unsigned,
       rest    :: binary >> = rest
       type = if id == 8 do :cancel else :request end
       {[type: type, index: index, begin: begin, length: length], rest}
  end

  def decode_message_type(len, id, rest) when id == 5 do
    l2 = len - 1
    << field :: binary-size(l2), rest :: binary >> = rest
    {[type: :bitfield, field: field], rest}
  end

  def decode_message_type(_len, id, rest) when id == 4 do
    << piece_index :: 32-integer-big-unsigned, rest :: binary >> = rest
    {[type: :have, piece_index: piece_index], rest}
  end

  def decode_message_type(_len, id, rest) when id == 3 do
    {[type: :not_interested], rest}
  end

  def decode_message_type(_len, id, rest) when id == 2 do
    {[type: :interested], rest}

  end

  def decode_message_type(_len, id, rest) when id == 1 do
    {[type: :unchoke], rest}
  end

  def decode_message_type(_len, id, rest) when id == 0 do
    {[type: :choke], rest}
  end

end
