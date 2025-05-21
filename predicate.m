function flag= predicate(region)
      sd= std2(region);
      m= mean2(region);
      %flag= (sd> 10)& (m> 0)& (m< 125);
      flag = (sd > 0.02) & (m > 0.1) & (m < 0.9);

end