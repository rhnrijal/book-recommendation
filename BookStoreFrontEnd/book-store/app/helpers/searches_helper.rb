module SearchesHelper
  def highlighter(string)
    final_string = truncate(string, :length => 66)
    downcased_string = final_string.downcase
    @words.each do |word|
      tag_start = downcased_string.index(word)
      if tag_start
        tag_end = tag_start+word.length
        final_string.insert(tag_end, '</b>').insert(tag_start, '<b>')
        downcased_string.insert(tag_end, '</b>').insert(tag_start, '<b>')
      end
    end
    final_string.html_safe
  end
end
