import React from 'react';
import {Composition} from 'remotion';
import lesson from '../build/lesson.json';
import {Lesson} from './Lesson';

export const RemotionRoot: React.FC = () => {
  const totalFrames = lesson.scenes.reduce(
    (sum: number, scene: any) => sum + Math.ceil(Number(scene.duration || 5) * Number(lesson.fps || 30)),
    0
  );

  return (
    <Composition
      id="Lesson"
      component={Lesson}
      durationInFrames={Math.max(1, totalFrames)}
      fps={Number(lesson.fps || 30)}
      width={Number((lesson as any).width || 1920)}
      height={Number((lesson as any).height || 1080)}
      defaultProps={{lesson}}
    />
  );
};
