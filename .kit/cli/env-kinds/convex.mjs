// ファイルの値のうち、Convex のどの deployment を向くかを名乗っているものを読む。
// 返すのは、deployment の名前、手元なら "local"、契約の urls に書くべきドメインなら URL。
const HOST = /^https?:\/\/([a-z]+-[a-z]+-\d+)(?:\.[a-z0-9-]+)?\.convex\.(?:cloud|site)(?:[/:]|$)/;
const LOCAL = /^https?:\/\/(?:localhost|127\.0\.0\.1|\[::1\])(?:[/:]|$)/;
const KEY = /CONVEX(?:_[A-Z]+)*_(?:URL|ORIGIN)$/;

export function backends(pairs) {
  const out = [];
  for (const [key, value] of pairs) {
    const host = HOST.exec(value);
    if (host) out.push(host[1]);
    else if (/CONVEX_DEPLOYMENT$/.test(key)) out.push(/^(?:anonymous|local):/.test(value) ? "local" : value.replace(/^\w+:/, ""));
    else if (KEY.test(key)) out.push(LOCAL.test(value) ? "local" : value);
  }
  return out;
}
