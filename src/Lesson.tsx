import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {getTheme} from './themes';

type Scene = Record<string, any>;
type LessonData = {
  id: string;
  title: string;
  subtitle?: string;
  fps: number;
  theme?: string;
  scenes: Scene[];
};

const labels: Record<string, string> = {
  title: 'LESSON', text: 'EXPLAINER', formula: 'FORMULA', counter: 'GROWTH',
  comparison: 'COMPARE', steps: 'PROCESS', timeline: 'TIMELINE', quote: 'QUOTE',
  terminal: 'TERMINAL', code: 'CODE', diagram: 'DIAGRAM', chart: 'DATA', stat: 'STAT',
  definition: 'DEFINITION', example: 'EXAMPLE', quiz: 'QUIZ', answer: 'ANSWER',
  warning: 'WARNING', tip: 'TIP', summary: 'TAKEAWAY', cta: 'NEXT',
};

const captionChunks = (text: string, words = 9) => {
  const ws = text.trim().split(/\s+/).filter(Boolean);
  const out: string[] = [];
  for (let i = 0; i < ws.length; i += words) out.push(ws.slice(i, i + words).join(' '));
  return out.length ? out : [''];
};

export const Lesson: React.FC<{lesson: LessonData}> = ({lesson}) => {
  let start = 0;
  const theme = getTheme(lesson.theme);
  const total = lesson.scenes.reduce(
    (n, s) => n + Math.ceil(Number(s.duration || 5) * lesson.fps),
    0,
  );

  return (
    <AbsoluteFill style={{background: theme.background, color: theme.text}}>
      <Background theme={theme} />
      {lesson.scenes.map((scene, index) => {
        const duration = Math.ceil(Number(scene.duration || 5) * lesson.fps);
        const from = start;
        start += duration;

        return (
          <Sequence key={`${index}-${scene.heading}`} from={from} durationInFrames={duration}>
            <SceneView
              scene={scene}
              index={index}
              count={lesson.scenes.length}
              globalStart={from}
              totalFrames={total}
              theme={theme}
            />
            <Audio src={staticFile(`audio/scene-${String(index + 1).padStart(2, '0')}.mp3`)} />
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};

const Background: React.FC<{theme: any}> = ({theme}) => {
  const frame = useCurrentFrame();
  if (!theme.grid) return null;
  const x = interpolate(frame % 360, [0, 360], [0, 80]);
  return (
    <AbsoluteFill
      style={{
        opacity: 0.15,
        backgroundImage: `linear-gradient(${theme.border} 1px, transparent 1px), linear-gradient(90deg, ${theme.border} 1px, transparent 1px)`,
        backgroundSize: '80px 80px',
        backgroundPosition: `${x}px ${x}px`,
      }}
    />
  );
};

const SceneView: React.FC<any> = ({scene, index, count, globalStart, totalFrames, theme}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame, fps, config: {damping: 14, stiffness: 95, mass: 0.85}});
  const y = interpolate(enter, [0, 1], [52, 0]);
  const fade = interpolate(frame, [0, 12], [0, 1], {extrapolateRight: 'clamp'});
  const progress = Math.min(1, (globalStart + frame) / Math.max(1, totalFrames));

  const parts = captionChunks(scene.narration || '', 9);
  const sceneFrames = Math.max(1, Number(scene.duration || 5) * fps);
  const captionIndex = Math.min(
    parts.length - 1,
    Math.floor((frame / sceneFrames) * parts.length),
  );

  const layout = scene.layout || 'minimal';
  const panel: React.CSSProperties = {
    border: `1px solid ${theme.border}`,
    background: theme.panel,
    borderRadius: theme.radius,
  };

  const shellStyle: React.CSSProperties = {
    width: '100%',
    maxWidth: layout === 'minimal' ? 1180 : layout === 'big-number' ? 1250 : 1500,
    opacity: fade,
    transform: `translateY(${y}px)`,
    textAlign: layout === 'split' ? 'left' : 'center',
    fontFamily: layout === 'console' ? theme.mono : layout === 'editorial' ? 'Georgia, serif' : theme.font,
  };

  return (
    <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', padding: '105px 110px', fontFamily: theme.font}}>
      <div
        style={{
          position: 'absolute', top: 46, left: 68, right: 68,
          display: 'flex', justifyContent: 'space-between',
          fontSize: 20, fontWeight: 800, letterSpacing: 3, color: theme.muted,
        }}
      >
        <span>RICHMACK OS</span>
        <span>{String(index + 1).padStart(2, '0')} / {String(count).padStart(2, '0')}</span>
      </div>

      <div style={shellStyle}>
        <div style={{fontSize: scene.type === 'title' ? 96 : 76, fontWeight: 900, lineHeight: 1.04, letterSpacing: -2.5}}>
          {scene.heading}
        </div>

        {scene.subheading && (
          <div style={{fontSize: 38, color: theme.muted, marginTop: 26, lineHeight: 1.3}}>
            {scene.subheading}
          </div>
        )}

        {scene.formula && (
          <div style={{...panel, display: 'inline-block', marginTop: 48, padding: '34px 54px', fontFamily: theme.mono, fontSize: 104, color: theme.accent, fontWeight: 850}}>
            {scene.formula}
          </div>
        )}

        {scene.stat !== undefined && (
          <div style={{fontSize: 180, fontWeight: 950, color: theme.accent, marginTop: 40}}>
            {scene.stat}
          </div>
        )}

        {Array.isArray(scene.items) && (
          <div style={{display: 'grid', gap: 16, margin: '44px auto 0', maxWidth: 1080, textAlign: 'left'}}>
            {scene.items.map((x: string, i: number) => (
              <div key={i} style={{...panel, padding: '20px 26px', fontSize: 32, fontWeight: 700}}>
                <span style={{color: theme.accent, marginRight: 16}}>{String(i + 1).padStart(2, '0')}</span>{x}
              </div>
            ))}
          </div>
        )}

        {(scene.code || scene.command) && (
          <div style={{...panel, margin: '44px auto 0', maxWidth: 1150, padding: 30, textAlign: 'left', fontFamily: theme.mono, fontSize: 28, whiteSpace: 'pre-wrap', color: theme.accent2}}>
            {scene.command ? `$ ${scene.command}` : scene.code}
          </div>
        )}

        {scene.question && (
          <div style={{...panel, margin: '42px auto 0', maxWidth: 1120, padding: '28px 34px', fontSize: 38, fontWeight: 800}}>
            {scene.question}
          </div>
        )}

        {Array.isArray(scene.choices) && (
          <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, margin: '26px auto 0', maxWidth: 1050}}>
            {scene.choices.map((c: string, i: number) => (
              <div key={i} style={{...panel, padding: '18px 22px', fontSize: 28, fontWeight: 700}}>
                {String.fromCharCode(65 + i)}. {c}
              </div>
            ))}
          </div>
        )}

        {scene.left && scene.right && (
          <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28, marginTop: 46}}>
            <div style={{...panel, padding: 38, fontSize: 40, fontWeight: 800}}>{scene.left}</div>
            <div style={{...panel, padding: 38, fontSize: 40, fontWeight: 800, background: theme.panelStrong}}>{scene.right}</div>
          </div>
        )}
      </div>

      <div style={{position: 'absolute', left: '12%', right: '12%', bottom: 86, textAlign: 'center'}}>
        <div style={{display: 'inline-block', maxWidth: 1200, padding: '14px 22px', borderRadius: 18, background: 'rgba(0,0,0,.60)', fontSize: 30, lineHeight: 1.28, fontWeight: 750}}>
          {parts[captionIndex]}
        </div>
      </div>

      <div style={{position: 'absolute', left: 68, right: 68, bottom: 48, height: 4, background: theme.panelStrong, borderRadius: 999, overflow: 'hidden'}}>
        <div style={{height: '100%', width: `${progress * 100}%`, background: `linear-gradient(90deg, ${theme.accent}, ${theme.accent2})`}} />
      </div>
    </AbsoluteFill>
  );
};
