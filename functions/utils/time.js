function calculateTotalTime(prep, cook) {
  const parse = (s) => {
    if (!s) return 0;
    const h = s.match(/(\d+)\s*h/i);
    const m = s.match(/(\d+)\s*min/i);
    return (h ? +h[1] * 60 : 0) + (m ? +m[1] : 0);
  };

  const total = parse(prep) + parse(cook);
  if (!total) return "";

  const h = Math.floor(total / 60);
  const m = total % 60;

  if (h && m) return `${h} h ${m} min`;
  if (h) return `${h} h`;
  return `${m} min`;
}

module.exports = { calculateTotalTime };