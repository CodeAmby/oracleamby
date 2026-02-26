import Head from 'next/head'
export default function Home(){
  return (
    <div>
      <Head><title>Amby Demo Product</title></Head>
      <main style={{padding: '2rem', fontFamily: 'Arial'}}>
        <h1>Amby Demo Product</h1>
        <p>This is a minimal demo landing page deployed by your agent.</p>
        <a href="/product.pdf" download>Download demo PDF</a>
      </main>
    </div>
  )
}
