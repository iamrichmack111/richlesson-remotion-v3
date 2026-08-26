export type ThemeName =
  | 'cinematic-glass'
  | 'blueprint'
  | 'terminal-noir'
  | 'neon-grid'
  | 'editorial'
  | 'paper-ink'
  | 'retro-future'
  | 'classroom'
  | 'data-lab'
  | 'minimal-luxury'
  | 'space-console'
  | 'industrial'
  | 'midnight-academy'
  | 'signal'
  | 'monochrome';

export type Theme = {
  name: ThemeName;
  label: string;
  background: string;
  panel: string;
  panelStrong: string;
  border: string;
  text: string;
  muted: string;
  accent: string;
  accent2: string;
  font: string;
  mono: string;
  grid: boolean;
  glow: boolean;
  radius: number;
  headingTransform?: 'uppercase' | 'none';
};

export const THEMES: Record<ThemeName, Theme> = {
  'cinematic-glass': {
    name:'cinematic-glass', label:'Cinematic Glass',
    background:'radial-gradient(circle at 20% 20%, rgba(82,105,255,.20), transparent 34%), radial-gradient(circle at 80% 70%, rgba(0,220,190,.12), transparent 30%), linear-gradient(180deg,#090d14,#05070b)',
    panel:'rgba(255,255,255,.055)', panelStrong:'rgba(255,255,255,.09)',
    border:'rgba(255,255,255,.16)', text:'#ffffff', muted:'rgba(255,255,255,.72)',
    accent:'#8fa6ff', accent2:'#75f2d2', font:'Inter, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:true, radius:30
  },
  blueprint: {
    name:'blueprint', label:'Blueprint',
    background:'linear-gradient(180deg,#06182b,#08243d)',
    panel:'rgba(255,255,255,.035)', panelStrong:'rgba(255,255,255,.07)',
    border:'rgba(167,220,255,.26)', text:'#eaf7ff', muted:'rgba(224,244,255,.68)',
    accent:'#8cd5ff', accent2:'#d4f3ff', font:'Inter, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:false, radius:8
  },
  'terminal-noir': {
    name:'terminal-noir', label:'Terminal Noir',
    background:'linear-gradient(180deg,#050807,#010201)',
    panel:'rgba(94,255,146,.045)', panelStrong:'rgba(94,255,146,.08)',
    border:'rgba(94,255,146,.22)', text:'#d8ffe5', muted:'rgba(185,255,205,.62)',
    accent:'#78ff9d', accent2:'#d8ffe5', font:'ui-monospace, SFMono-Regular, Menlo, monospace',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:true, radius:6
  },
  'neon-grid': {
    name:'neon-grid', label:'Neon Grid',
    background:'radial-gradient(circle at 50% 18%, rgba(232,66,255,.16), transparent 28%), linear-gradient(180deg,#120723,#05050c)',
    panel:'rgba(255,255,255,.05)', panelStrong:'rgba(255,255,255,.09)',
    border:'rgba(229,112,255,.25)', text:'#ffffff', muted:'rgba(255,255,255,.68)',
    accent:'#ef72ff', accent2:'#6fffe8', font:'Inter, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:true, radius:24
  },
  editorial: {
    name:'editorial', label:'Editorial',
    background:'linear-gradient(180deg,#f5f2eb,#e8e3d9)',
    panel:'rgba(20,20,20,.035)', panelStrong:'rgba(20,20,20,.06)',
    border:'rgba(20,20,20,.17)', text:'#171717', muted:'rgba(20,20,20,.62)',
    accent:'#6a2e2e', accent2:'#292929', font:'Georgia, Times New Roman, serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:false, glow:false, radius:2
  },
  'paper-ink': {
    name:'paper-ink', label:'Paper & Ink',
    background:'linear-gradient(180deg,#efe7d7,#e3d6c1)',
    panel:'rgba(56,43,26,.035)', panelStrong:'rgba(56,43,26,.065)',
    border:'rgba(56,43,26,.20)', text:'#2a2118', muted:'rgba(42,33,24,.62)',
    accent:'#7b3f26', accent2:'#253b34', font:'Georgia, Times New Roman, serif',
    mono:'Courier New, monospace', grid:false, glow:false, radius:10
  },
  'retro-future': {
    name:'retro-future', label:'Retro Future',
    background:'linear-gradient(180deg,#1c0c2f,#08131d)',
    panel:'rgba(255,191,91,.045)', panelStrong:'rgba(255,191,91,.08)',
    border:'rgba(255,196,98,.22)', text:'#fff0c9', muted:'rgba(255,240,201,.65)',
    accent:'#ffbd59', accent2:'#70e1d2', font:'Trebuchet MS, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:true, radius:18
  },
  classroom: {
    name:'classroom', label:'Classroom',
    background:'linear-gradient(180deg,#12372a,#0c261d)',
    panel:'rgba(245,242,225,.045)', panelStrong:'rgba(245,242,225,.08)',
    border:'rgba(245,242,225,.18)', text:'#f6f1de', muted:'rgba(246,241,222,.65)',
    accent:'#f1d875', accent2:'#d8efe3', font:'Trebuchet MS, Arial, sans-serif',
    mono:'Courier New, monospace', grid:false, glow:false, radius:14
  },
  'data-lab': {
    name:'data-lab', label:'Data Lab',
    background:'linear-gradient(180deg,#071018,#09151f)',
    panel:'rgba(147,207,255,.04)', panelStrong:'rgba(147,207,255,.075)',
    border:'rgba(147,207,255,.18)', text:'#eaf6ff', muted:'rgba(220,240,255,.64)',
    accent:'#8bd3ff', accent2:'#7dffca', font:'Inter, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:false, radius:18
  },
  'minimal-luxury': {
    name:'minimal-luxury', label:'Minimal Luxury',
    background:'linear-gradient(180deg,#0b0b0d,#151419)',
    panel:'rgba(255,255,255,.035)', panelStrong:'rgba(255,255,255,.055)',
    border:'rgba(228,211,169,.17)', text:'#f7f4ec', muted:'rgba(247,244,236,.60)',
    accent:'#d8c08b', accent2:'#f7f4ec', font:'Georgia, Times New Roman, serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:false, glow:false, radius:22
  },
  'space-console': {
    name:'space-console', label:'Space Console',
    background:'radial-gradient(circle at 50% 0%, rgba(65,92,160,.20), transparent 35%), linear-gradient(180deg,#060913,#020307)',
    panel:'rgba(164,188,255,.04)', panelStrong:'rgba(164,188,255,.075)',
    border:'rgba(164,188,255,.18)', text:'#eef3ff', muted:'rgba(238,243,255,.62)',
    accent:'#9fb7ff', accent2:'#d4e0ff', font:'Inter, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:true, radius:12
  },
  industrial: {
    name:'industrial', label:'Industrial',
    background:'linear-gradient(180deg,#17191b,#0c0d0e)',
    panel:'rgba(255,255,255,.04)', panelStrong:'rgba(255,255,255,.07)',
    border:'rgba(255,255,255,.14)', text:'#f4f4f2', muted:'rgba(244,244,242,.60)',
    accent:'#d7a63b', accent2:'#e7e7e0', font:'Arial Narrow, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:false, glow:false, radius:4,
    headingTransform:'uppercase'
  },
  'midnight-academy': {
    name:'midnight-academy', label:'Midnight Academy',
    background:'linear-gradient(180deg,#101528,#070a12)',
    panel:'rgba(255,255,255,.04)', panelStrong:'rgba(255,255,255,.07)',
    border:'rgba(210,219,255,.15)', text:'#f4f6ff', muted:'rgba(235,239,255,.62)',
    accent:'#b9c7ff', accent2:'#f4f6ff', font:'Georgia, Times New Roman, serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:false, glow:false, radius:16
  },
  signal: {
    name:'signal', label:'Signal',
    background:'linear-gradient(135deg,#07100e,#11150d)',
    panel:'rgba(204,255,99,.04)', panelStrong:'rgba(204,255,99,.075)',
    border:'rgba(204,255,99,.18)', text:'#f3ffe1', muted:'rgba(243,255,225,.60)',
    accent:'#cbff63', accent2:'#ffffff', font:'Inter, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:true, glow:true, radius:20
  },
  monochrome: {
    name:'monochrome', label:'Monochrome',
    background:'linear-gradient(180deg,#f7f7f7,#dedede)',
    panel:'rgba(0,0,0,.03)', panelStrong:'rgba(0,0,0,.06)',
    border:'rgba(0,0,0,.16)', text:'#111111', muted:'rgba(17,17,17,.60)',
    accent:'#111111', accent2:'#555555', font:'Helvetica Neue, Arial, sans-serif',
    mono:'ui-monospace, SFMono-Regular, Menlo, monospace', grid:false, glow:false, radius:0
  }
};

export const getTheme = (name?: string): Theme =>
  THEMES[(name as ThemeName) || 'cinematic-glass'] || THEMES['cinematic-glass'];
