require 'nokogiri'
require 'watir'
require 'watir-scroll'

# Simulate a browser with javascript support
browser = Watir::Browser.new(:phantomjs)

# Start with the most popular image on imgur as the first comment section to crawl
queue = ["zzdj9VS"]

# Hash of images and timestamps
discovered_imgs = {}

time_start =  Time.now.to_f

# stop at some number of images.
limit = 1000

while queue.length != 0 && (discovered_imgs.keys.length < limit)
  puts "explored: #{discovered_imgs.keys.length}"
  puts "enqueued: #{queue.length}"

  seed_url = queue.shift

  if discovered_imgs[seed_url] != nil
    # Don't explore this image if we already have seen it.
    next
  else
    discovered_imgs[seed_url] = Time.now.to_f - time_start
  end

  browser.goto("imgur.com/gallery/" + seed_url)

  # Update the comment count until we can load no more.
  last_loaded = nil

  while true

    browser.scroll.to :bottom  # scrolls element to the bottom
    html = Nokogiri::HTML(browser.html)

    begin
      comment_container =  html.css("body").at_css("div#inside").at_css("div#comments-container")
      comments = comment_container.at_css("div#comments").at_css("div#captions").search("a")
    rescue
      # no comments on this image...return
      break
    end
    if(comments.length != last_loaded)
      last_loaded = comments.length
      # let the page load some more
      sleep (0.5)
    else
      break
    end
  end

  # Go through every link in the comment and extract the ones that may lead to new imgur galleries.
  new_links = []
  comments.each { |c| new_links << c['href']}

  # imgur links are always hardlinked and include i.imgur.com...
  valid_links = new_links.reject {|i| not i.include? "i.imgur.com"} 
  ids = valid_links.map {|l| l.split("/")[-1].split(".")[0]}
  puts ids
  queue += ids
end
puts "finished! Found #{discovered_imgs.keys.length} images."

open('imgur.csv', 'w') do |f|
  discovered_imgs.each do |key, time|
    f.puts "#{key}, #{time}"
  end
end