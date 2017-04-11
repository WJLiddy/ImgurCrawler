require 'nokogiri'
require 'watir'
require 'watir-scroll'
require 'thread'
Thread.abort_on_exception = true

class Scraper

  def initialize(limit,thread_count)
    # stop at some number of images.
    @limit = limit

    # thread count 
    @thread_count = thread_count

    @browsers = []
    @thread_count.times do
      @browsers <<  Watir::Browser.new(:phantomjs)
    end

    @queue = Queue.new

    # Start with the most popular images on imgur as the first comment section to crawl
    ["zzdj9VS","mNiso","PmXqPEy","RLKixQW","9zUk0Pb"].each {|q| @queue << q}

    # Hash of images and timestamps
    @mutex = Mutex.new
    @discovered_imgs = {}

    @time_start =  Time.now.to_f
  end

  def start
    th = nil
    @thread_count.times do |tid|
      puts tid
      th = Thread.new {
        while @queue.length != 0 
          done_searching = (@discovered_imgs.keys.length >= @limit)
          break if done_searching
          search(@browsers[tid],@queue.pop)
        end
      }
    end

    th.join
    puts "finished! Found #{@discovered_imgs.keys.length} images."

    open('imgur.csv', 'w') do |f|
      @discovered_imgs.each do |key, time|
        f.puts "#{key}, #{time}"
      end
    end
  end

  def search(browser,seed_url)
    puts "explored: #{@discovered_imgs.keys.length}"
    puts "enqueued: #{@queue.length}"
    STDOUT.flush

    #mutex.synchronize |m|
      if @discovered_imgs[seed_url] != nil
        # Don't explore this image if we already have seen it.
        return
      else
        @discovered_imgs[seed_url] = Time.now.to_f - @time_start
      end
    #end

    begin
      browser.goto("imgur.com/gallery/" + seed_url)
    rescue => e
      puts e
    end

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
        return
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
    #puts ids
    ids.each {|q| @queue << q}
  end
end

Scraper.new(100,2).start