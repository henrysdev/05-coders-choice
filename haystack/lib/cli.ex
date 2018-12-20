defmodule CLI do
  @moduledoc """
  CLI is a module for interacting with Haystack through the commandline. 
  [ Usage ]
    Fragmentation
    fragment --in <string> --count <integer> --keyfile <string> --out <string>
    fragment --in <string> --count <integer> --out <string>
    
    Reassembly
    reassemble --in <string> --keyfile <path/to/keyfile> --out <string>
    reassemble --in <string> --out <string>
    
  [ Parameters ]
    --in | -i
      path to the input file (for fragmentation) or the input directory (for reassembly).
    --count | -c
      number of fragments to split the file into during fragmentation.
    --keyfile | -k
      path to a file containing the plaintext password to be used for encryption (for fragmentation) or decryption(for reassembly).
    --out | -o
      path to the output directory where fragments (for fragmentation) or the original file (for reassembly) will be located.
  """

  def main(argv) do
    parse_args(argv)
  end

  defp parse_args(argv) do
    switches = [
      in: :string, 
      count: :integer, 
      keyfile: :string, 
      out: :string, 
      save_orig: :boolean,
    ]
    aliases = [
      i: :in, 
      c: :count, 
      k: :keyfile, 
      o: :out, 
      s: :save_orig,
    ]
    parse = OptionParser.parse(argv, switches: switches, aliases: aliases)
    case parse do
      {opts,  ["fragment"], _}   -> map_params(opts, :fragment)
      {opts,  ["reassemble"], _} -> map_params(opts, :reassemble)
      {_opts, ["help" | _], _}   -> help_dialog()
      _ -> IO.puts "Invalid parameters"
    end
  end

  # Maps given parameters to the correct handler for the given 
  # password entry method.
  defp map_params(opts, :fragment) do
    # TODO validate that all necessary params are not nil before calling function!
    case opts[:keyfile] do
      nil -> Haystack.fragment(
        opts[:in],
        opts[:count],
        password_get("Enter the password to encrypt with: "),
        opts[:out],
        opts[:save_orig]
      )
      _  -> Haystack.fragment(
        opts[:in],
        opts[:count],
        opts[:keyfile] |> Utils.File.parse_keyfile(),
        opts[:out],
        opts[:save_orig]
      )
    end
  end
  defp map_params(opts, :reassemble) do
    # TODO validate that all necessary params are not nil before calling function!
    case opts[:keyfile] do
      nil -> Haystack.reassemble(
        opts[:in],
        password_get("Enter the password to decrypt with: "),
        opts[:out]
      )
      _  -> Haystack.reassemble(
        opts[:in],
        opts[:keyfile] |> Utils.File.parse_keyfile(),
        opts[:out]
      )
    end
  end

  # Returns user-entered password from (hidden) stdin.
  # https://github.com/hexpm/hex/blob/5dd8ae020dc4c31bc662e490c79221423fc5d9f6/lib/mix/tasks/hex/util.ex#L46-L74
  defp password_get(prompt) do
    pid = spawn_link fn -> loop(prompt) end
    ref = make_ref()

    value = IO.gets(prompt <> " ")

    send pid, {:done, self(), ref}
    receive do: ({:done, pid, ref}  -> :ok)

    value
  end

  defp loop(prompt) do
    receive do
      {:done, parent, ref} ->
        send parent, {:done, self(), ref}
        IO.write :standard_error, "\e[2K\r"
    after
      1 ->
        IO.write :standard_error, "\e[2K\r#{prompt} "
        loop(prompt)
    end
  end

  @doc """
  Returns instructions for using the CLI.
  """
  def help_dialog() do
    """
    [ Usage ]
      Fragmentation
      fragment --in <string> --count <integer> --keyfile <string> --out <string>
      fragment --in <string> --count <integer> --out <string>
      fragment --in <string> --count <integer> --out <string> --save_orig <true boolean flag>
      
      Reassembly
      reassemble --in <string> --keyfile <path/to/keyfile> --out <string>
      reassemble --in <string> --out <string>
      reassemble --in <string> --out <string> --save_orig <true boolean flag>
    
    [ Parameters ]
      --in | -i
        path to the input file (for fragmentation) or the input directory (for reassembly).
      --count | -c
        number of fragments to split the file into during fragmentation.
      --keyfile | -k
        path to a file containing the plaintext password to be used for encryption (for fragmentation) or decryption(for reassembly).
      --out | -o
        path to the output directory where fragments (for fragmentation) or the original file (for reassembly) will be located.
      --save_orig | -s
        (optional) flag that if set, will not delete the original file after fragmentation.
    """ |> IO.puts()
  end

end
