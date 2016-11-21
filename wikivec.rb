require 'measurable'
require 'nokogiri'
require 'open-uri'

class Word2Vec
  def initialize(filepath)
    @vectors = {}

    puts "Loading vectors..."
    File.open(filepath) do |f|
      f.each_line do |line|
        fields = line.rstrip.split(' ')
        word = fields.first
        values = fields[1..-1].map(&:to_f)
        vectors[word] = values
      end
    end

    puts "Loaded #{vectors.keys.length} vectors"
  end

  # checks whether a word is present in the vectors
  def word_present?(word)
    vectors.keys.include?(word)
  end

  # takes an array of words and returns only those present in the vectors
  def filter_to_present(words)
    vectors.keys & words
  end

  def distance(word1, word2)
    [word1, word2].each do |word|
      raise "#{word} not present" unless word_present?(word)
    end

    Measurable.euclidean(vectors[word1], vectors[word2])
  end

  # avoid printing out all the vectors when an instance is inspected
  def inspect
    ""
  end

  private

  attr_accessor :vectors
end

class WikiVec
  BLACKLIST = ["edit", "^"]
  def initialize(w2v:)
    @w2v = w2v
  end

  def parse(url, target_word)
    doc = Nokogiri::HTML(open(url))

    puts ""
    puts "#{doc.css("h1#firstHeading").text} => #{target_word}... RACE!"
    puts ""

    _parse(url, target_word, [])
  end

  def _parse(url, target_word, history)
    doc = Nokogiri::HTML(open(url))
    puts "#{doc.css("h1#firstHeading").text} =>"
    links = doc.
            css("#mw-content-text a").
            select{ |a| a.attributes["href"].to_s[0] == "/" } # internal wikipedia links only
    link_words = links.map { |a| a.text.downcase }
    present_words = w2v.filter_to_present(link_words)
    present_words -= history # we don't want to revisit a page we already saw, to avoid cycles
    present_words -= BLACKLIST # avoid certain special links
    # puts "#{present_words.length}/#{link_words.length} words present in vectors: #{present_words.first(3)}..."

    if present_words.include?(target_word)
      puts target_word
      return
    end

    min_dist = 1000
    closest_word = nil

    present_words.each do |word|
      dist = w2v.distance(word, target_word)
      if dist < min_dist
        min_dist = dist
        closest_word = word
        # puts "#{word} -> #{target_word}: #{dist}" # useful for debugging search
      end
    end

    # puts "-> #{closest_word}"

    history << closest_word

    link_to_follow = links.find { |link| link.text.downcase == closest_word }
    next_url = process_href(link_to_follow.attributes["href"].to_s)
    _parse(next_url, target_word, history)
  end

  # avoid printing out all the vectors when an instance is inspected
  def inspect
    ""
  end

  private

  attr_accessor :w2v

  # turns a relative wikipedia link into an absolute one
  def process_href(href)
    "https://en.wikipedia.org" + href
  end
end


w2v = Word2Vec.new("data/glove.6B.100d.txt");

wv = WikiVec.new(w2v: w2v);
wv.parse("https://en.wikipedia.org/wiki/Disaronno", "apple")

