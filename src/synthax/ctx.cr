module Sthx
  # Represents the parsing context.
  #
  # - *reader* is the `Char::Reader` used for reading.
  # - *root* is the current root of the parse tree (see `Tree`).
  #
  # Note that `Ctx` is a *mutable struct* if *reader* is interacted with,
  # so beware of dragons.
  record Ctx, reader : Char::Reader, root : Tree do
    # Returns the current character of this context's reader.
    def char : Char
      @reader.current_char
    end

    # Returns this context's progress (position) within the source string.
    def progress : Int32
      @reader.pos
    end

    # Advances this reader one character forward.
    def advance : self
      @reader.next_char

      self
    end

    # Returns whether this context's reader is at the end of its string.
    def at_end? : Bool
      !@reader.has_next?
    end

    # Returns a copy of this context where the root is set to be a
    # tree with the given *id*.
    def rebase(id : String) : self
      copy_with(root: Tree.new(id, @reader.pos))
    end

    # Returns a "reading-terminated" copy of this context where the root
    # tree spans up to the current position of the reader.
    def terminate : self
      copy_with(root: @root.span(to: @reader))
    end

    # Returns a copy of this context which has *other* adopted. *Adoption*
    # means tree adoption (*other*'s root is made the subtree of `self`'s)
    # and the picking of the reader which has the most progress out of
    # `self`'s and *other*'s.
    def adopt(other : Ctx)
      other = other.terminate

      copy_with(
        root: @root.adopt(other.root),
        reader: (progress < other.progress ? other : self).reader,
      )
    end
  end

  # Wraps a parsing context *ctx* and represents a parse error.
  record Err, ctx : Ctx do
    # See the same method in `Ctx`.
    delegate :progress, :char, to: @ctx

    # *Computes* and returns a `{line, column}` tuple with the line and
    # column where the error occured, *counting both from 1*.
    def line_and_column : {Int32, Int32}
      line, col, fst = 1, 1, true
      reader = @ctx.reader
      while reader.has_previous?
        if reader.current_char == '\n'
          line += 1
          fst = false
        end
        col += 1 if fst
        reader.previous_char
      end
      {line, col}
    end

    # CAUTION JUNK IN AREA

    def humanize(io : IO, *, filename = nil, color = false, readout = false, lookaround = 2)
      err_lineno, err_column = line_and_column

      io << "error:".colorize.red.bold.toggle(color)
      if char == '\0'
        io << " unexpected end-of-input"
      else
        io << " syntax error near '" << char << "'"
      end
      io << " at line " << err_lineno << ", column " << err_column
      io << " (" << filename << ":" << err_lineno << ":" << err_column << ")" if filename

      return unless readout

      io.puts
      io.puts

      @ctx.reader.string
        .each_line.with_index
        .skip(Math.max(err_lineno - lookaround, 0))
        .first(lookaround*2)
        .each do |line, line_index|
          lineno = line_index + 1

          if line.size > 40
            offset = Math.max(err_column - 20, 0)
            trunk = line[offset...Math.min(err_column + 20, line.size)]
          else
            offset = 0
            trunk = line
          end

          linenr = "  #{lineno}|"
          io << linenr << ' '
          io << "<..".colorize.dim.toggle(color) unless offset.zero?
          io << (trunk.blank? ? "⏎".colorize.dim.toggle(color) : trunk)
          io << "..>".colorize.dim.toggle(color) unless trunk.size == line.size
          io.puts

          next unless lineno == err_lineno

          io << " " * (linenr.size - 1) << "|"

          caret_padding = offset.zero? ? err_column : err_column - offset + 2
          io << " " * caret_padding << "^ here".colorize.red.bold.toggle(color)
          io.puts
        end
    end
  end
end
