void initTwitter() {
  AtomFeed feed;
  
  if (ONLINE) {
    feed = AtomFeed.newFromURL("http://search.twitter.com/search.atom?q=" + QUERY);
  }
  else {
    feed = AtomFeed.newFromStream(openStream("search.atom"));
  }
  
  HashMap<String, Integer> uniqueAuthors = new HashMap<String, Integer>();
  for (AtomEntry e : feed.entries) {
    String name = e.author.name;
    if (uniqueAuthors.containsKey(name)) {
      int freq = uniqueAuthors.get(name);
      uniqueAuthors.put(name, ++freq);
      println(name + " = " + freq);
    }
    else {
      println("new name: " + name);
      uniqueAuthors.put(name, 1);
    }
  }
  
  Collections.sort(feed.entries, new Comparator<AtomEntry>() {
    public int compare(AtomEntry a, AtomEntry b) {
      long atime = a.timePublished.toGregorianCalendar().getTimeInMillis();
      long btime = b.timePublished.toGregorianCalendar().getTimeInMillis();
      return (int)(atime - btime);
    }
  });
  
  // find the minimum and maximum times of the tweets
  long tmin = feed.entries.get(0).timePublished.toGregorianCalendar().getTimeInMillis();
  long tmax = feed.entries.get(feed.entries.size() - 1).timePublished.toGregorianCalendar().getTimeInMillis();
  
  // map entries on grid
  List<String> names = new ArrayList<String>(uniqueAuthors.keySet());
  for (AtomEntry e : feed.entries) {
    // get the index of the current author
    int a = names.indexOf(e.author.name);
    
    // get the time of this tweet
    long t = e.timePublished.toGregorianCalendar().getTimeInMillis();
    
    // map to screen coordinates
    float x = map(a, 0, uniqueAuthors.size() - 1, -RESX / 2, RESX / 2 - 1);
    float y = map(t, tmin, tmax, RESY/2 - 1, -RESY / 2);
    
    // make a TweetPoint
    TweetPoint tp = new TweetPoint(new Vec2D(x, y), e);
    tweets.add(tp);
  }
}

