export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })
  try {
    const body = req.body || {}
    const { email } = body
    const fs = require('fs')
    const path = require('path')
    // Use process.cwd() so the API writes into the project directory on Vercel deployments
    const ROOT = process.cwd()
    const STATE_DIR = path.join(ROOT, 'workspace', 'state')
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
