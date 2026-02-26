import Head from 'next/head'
import { useState } from 'react'
export default function Home(){
  const [email, setEmail] = useState('')
  const [msg, setMsg] = useState('')
  async function buy(e){
    e.preventDefault()
    setMsg('Processing...')
    try{
      const res = await fetch('/api/checkout', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({email})})
      const j = await res.json()
      if(j.ok) setMsg('Purchase simulated — proposal id ' + j.id)
      else setMsg('Error')
    }catch(err){setMsg('Error')}
  }
  return (
    <div>
      <Head><title>Amby Demo Product</title></Head>
      <main style={{padding: '2rem', fontFamily: 'Arial'}}>
        <h1>Amby Demo Product</h1>
        <p>This is a minimal demo landing page deployed by your agent.</p>
        <a href="/product.pdf" download>Download demo PDF</a>
        <hr style={{margin:'20px 0'}} />
        <form onSubmit={buy} style={{maxWidth:400}}>
          <label>Email (optional)</label>
          <input value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com" style={{width:'100%',padding:8,marginTop:8,marginBottom:8}} />
          <button type="submit" style={{padding:'8px 12px'}}>Buy (simulate)</button>
        </form>
        {msg && <p style={{marginTop:12}}>{msg}</p>}
      </main>
    </div>
  )
}
