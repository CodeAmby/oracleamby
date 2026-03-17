export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })
  try {
    const body = req.body || {}
    const { email } = body
    const fs = require('fs')
    const path = require('path')
    // Use process.cwd() so the API writes into the project directory on Vercel deployments
    const ROOT = process.cwd()
    const os = require('os')
    const STATE_DIR = path.join(os.tmpdir(), 'amby_state')
    const PROPOSAL_DIR = path.join(STATE_DIR, 'proposals')
    if (!fs.existsSync(PROPOSAL_DIR)) fs.mkdirSync(PROPOSAL_DIR, { recursive: true })
    const id = Date.now().toString()
    const to = '0x1111111111111111111111111111111111111111'
    const proposal = {
      id,
      to,
      value_wei: '10000000000000000', // 0.01 ETH
      value_usd: '10',
      purchaser: email || 'anonymous',
      reason: 'Fake checkout purchase',
      status: 'pending'
    }
    fs.writeFileSync(path.join(PROPOSAL_DIR, `proposal-${id}.json`), JSON.stringify(proposal, null, 2))
    // persist to GitHub by creating a gist-style file via GitHub API if token available
    try {
      const child_process = require('child_process')
      const gh_token = child_process.execSync("security find-generic-password -s GITHUB_TOKEN -a amby -w || true", {encoding:'utf8'}).trim()
      if (gh_token) {
        const axios = require('axios')
        const repoOwner = 'CodeAmby'
        const repo = 'oracleamby'
        const pathInRepo = `workspace/state/proposals/proposal-${id}.json`
        const content = Buffer.from(JSON.stringify(proposal, null, 2)).toString('base64')
        // create file via GitHub API: create a blob + create a commit is complex; use a simple create-or-update file endpoint
        const url = `https://api.github.com/repos/${repoOwner}/${repo}/contents/${pathInRepo}`
        const headers = { Authorization: `token ${gh_token}`, 'User-Agent':'amby-agent' }
        // try GET to see if file exists
        let sha = null
        try {
          const getResp = await axios.get(url, {headers})
          sha = getResp.data.sha
        } catch(err) {
          // not found -> will create
        }
        const putPayload = { message: `Add proposal ${id}`, content, committer: { name: 'Amby Bot', email: 'amby@local' } }
        if (sha) putPayload.sha = sha
        await axios.put(url, putPayload, {headers})
      }
    } catch (gitErr) {
      // non-fatal: log but continue
      console.error('GitHub persist error', gitErr.message || gitErr)
    }
    // fire telegram notification if helper exists
    const tg = path.join(ROOT, 'workspace', 'scripts', 'telegram_send.sh')
    if (fs.existsSync(tg)) {
      const child = require('child_process').spawnSync(tg, [`[Amby] Fake checkout created proposal ${id} for ${proposal.value_usd} USD`])
    }
    return res.status(200).json({ ok: true, id })
  } catch (e) {
    console.error(e)
    return res.status(500).json({ error: 'server error' })
  }
}
