module SearchesHelper
  def highlighter(string)
    downcased_string = string.downcase
    @words.each do |word|
      tag_start = downcased_string.index(word)
      if tag_start
        tag_end = tag_start+word.length
        string.insert(tag_end, '</b>').insert(tag_start, '<b>')
        downcased_string.insert(tag_end, '</b>').insert(tag_start, '<b>')
      end
    end
    string.html_safe
  end
end
