// GitHub Sponsors と Ko-fi のユーザー名。変えるときは .github/FUNDING.yml も合わせる。
const supportUsername = 'yuto343';

export const site = {
  // 最新の Release の zip。publish.sh が、版の付かない akapen.zip という名前でも上げる。
  downloadUrl: 'https://github.com/yuto343/akapen/releases/latest/download/akapen.zip' as string | null,
  // 自前の tap（yuto343/homebrew-tap）から入れるコマンド。
  brewInstallCommand: 'brew install --cask yuto343/tap/akapen',
  githubSponsorsUrl: `https://github.com/sponsors/${supportUsername}`,
  kofiUrl: `https://ko-fi.com/${supportUsername}`,
  xUrl: 'https://x.com/uchoco898',
  githubUrl: 'https://github.com/yuto343/akapen',
  authorGithubUrl: 'https://github.com/yuto343',
  ogImage: '/akapen-icon.png',
  // 公開ドメインは未定。決まったら origin を入れ、OGP と代替言語 URL を絶対 URL にする。
  origin: null as string | null
};

export const siteUrl = (path: string): string => site.origin ? new URL(path, site.origin).href : path;
