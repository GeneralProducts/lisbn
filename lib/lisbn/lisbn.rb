class Lisbn < String
  def isbn
    upcase.gsub(/[^0-9X]/, '')
  end

  def valid?
    case isbn.length
      when 10
        valid_isbn_10?
      when 13
        valid_isbn_13?
      else
        false
    end
  end

  def isbn10
    return unless valid?
    return isbn if isbn.length == 10

    isbn[3..-2] + isbn_10_checksum
  end

  def isbn13
    return unless valid?
    return isbn if isbn.length == 13

    '978' + isbn[0..-2] + isbn_13_checksum
  end

  def parts
    return unless isbn13

    group = prefix = nil

    RANGES.each_pair do |g, prefixes|
      next unless isbn13.match("^#{g}")
      group = g

      pre_loc = group.length
      prefixes.each do |p|
        number = isbn13.slice(pre_loc, p[:length]).to_i
        next unless p[:range].include?(number)

        prefix = p.merge(:number => number)
        break
      end

      break
    end

    # In the unlikely event we can't categorize it...
    return unless group && prefix

    prefix = sprintf("%0#{prefix[:length]}d", prefix[:number])
    [group[0..2], group[3..-1], prefix, isbn13[(group.length + prefix.length)..-2], isbn13[-1..-1]]
  end

  cache_method :isbn, :valid?, :isbn10, :isbn13, :parts

private

  def isbn_10_checksum
    base = isbn.length == 13 ? isbn[3..-2] : isbn[0..-2]

    products = base.each_char.each_with_index.map do |chr, i|
      chr.to_i * (10 - i)
    end

    remainder = products.inject(0) {|m, v| m + v} % 11
    case remainder
      when 0
        0
      when 1
        'X'
      else
        11 - remainder
    end.to_s
  end

  def isbn_13_checksum
    base = (isbn.length == 13 ? '' : '978') + isbn[0..-2]

    products = base.each_char.each_with_index.map do |chr, i|
      chr.to_i * (i % 2 == 0 ? 1 : 3)
    end

    remainder = products.inject(0) {|m, v| m + v} % 10
    (remainder == 0 ? 0 : 10 - remainder).to_s
  end

  def valid_isbn_10?
    return false unless isbn.match(/^[0-9]{9}[0-9X]$/)
    isbn[-1..-1] == isbn_10_checksum
  end

  def valid_isbn_13?
    return false unless isbn.match(/^[0-9]{13}$/)
    isbn[-1..-1] == isbn_13_checksum
  end

  def self.ranges
    rngs = Hash.from_xml(File.read(File.dirname(__FILE__) + '/../../data/RangeMessage.xml'))
    Array.wrap(rngs["ISBNRangeMessage"]["RegistrationGroups"]["Group"]).inject({}) do |memo, group|
      prefix = group["Prefix"].gsub(/-/, '')
      ranges = Array.wrap(group["Rules"]["Rule"]).map do |rule|
        length = rule["Length"].to_i
        {:range => Range.new(*rule["Range"].split("-").map {|r| r[0..(length - 1)].to_i }), :length => length}
      end

      memo.update(prefix => ranges)
    end
  end

  RANGES = ranges
end
