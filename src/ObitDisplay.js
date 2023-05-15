import { useEffect, useState } from "react";
import { v4 as uuidv4 } from 'uuid';


function ObitDisplay({ setShowNewObituaryScreen, obituaries, setObituaries }) {
  const [showDropdown, setShowDropdown] = useState({});
  const [isPlaying, setIsPlaying] = useState(false);
  const [audioElement, setAudioElement] = useState(null);

  useEffect(() => {
    async function get_obituaries() {
      const res = await fetch(
        "https://p2fzxu4vzdmyvuykry3yh2kwnq0heoqz.lambda-url.ca-central-1.on.aws/",
        {
          method: "GET"
        }
      );

      const jsonRes = await res.json();
      console.log(jsonRes);

      if (jsonRes && jsonRes.length != null) {
        const mappedObituaries = jsonRes.map((obituary) => ({
          ...obituary,
          audioPlaying: false,
        }));
        setObituaries(mappedObituaries);
        if (jsonRes.length > 0) {
          const newestObit = mappedObituaries[jsonRes.length - 1];
          setShowDropdown((prevState) => ({
            ...prevState,
            [newestObit.cloudinary_url]: true,
          }));
        }
        if (jsonRes.length > 1) {
          const secondNewestObit = mappedObituaries[jsonRes.length - 2];
          setShowDropdown((prevState) => ({
            ...prevState,
            [secondNewestObit.cloudinary_url]: false,
          }));
        }
      } else {
        setObituaries([]); // set notes to empty array
      }
    }
    get_obituaries();
  }, []); 
  
  const handleNewObituaryClick = () => {
    setShowNewObituaryScreen(true);
  };

  const formatDate = (date) => {
    const options = { month: "long", day: "numeric", year: "numeric" };
    return new Date(date).toLocaleDateString("en-US", options);
  };

  const createAudioElement = (polly, obituary) => {
    const audio = new Audio(polly);
    audio.onended = () => {
      setIsPlaying(false);
      const newObituaries = obituaries.map((o) =>
        o.cloudinary_url === obituary.cloudinary_url
          ? { ...o, audioPlaying: false }
          : o
      );
      setObituaries(newObituaries);
      setAudioElement(null);
    };
    setAudioElement(audio);
    return audio;
  };

  const handleAudioToggle = (event, obituary, polly) => {
    event.stopPropagation();
    const newObituaries = obituaries.map((o) =>
      o.cloudinary_url === obituary.cloudinary_url
        ? { ...o, audioPlaying: !o.audioPlaying }
        : { ...o, audioPlaying: false }
    );
    setObituaries(newObituaries);
    if (!audioElement || audioElement.src !== polly) {
      if (audioElement) {
        audioElement.pause();
        setAudioElement(null);
      }
      const audio = createAudioElement(polly, obituary);
      audio.play();
      setIsPlaying(true);
    } else if (isPlaying) {
      audioElement.pause();
      setIsPlaying(false);
    } else {
      audioElement.play();
      setIsPlaying(true);
    }
  };

  const handleDropdownToggle = (obituaryId) => {
    setShowDropdown((prevState) => ({
      ...prevState,
      [obituaryId]: !prevState[obituaryId],
    }));
  };

  return (
    <div id="container">
      <header>
        <div id="app-header">
          <h1>The Last Show</h1>
          <div onClick={handleNewObituaryClick}>
            <button className="log">+ New Obituary</button>
          </div>
        </div>
      </header>

      <div id="main-container">
        {obituaries.length > 0 ? (
          <div id="obit-holder">
            {obituaries.map((obituary) => (
              <div
                key={obituary.cloudinary_url}
                id="obit-preview"
                onClick={() => handleDropdownToggle(obituary.cloudinary_url)}
              >
                <img
                  src={obituary.cloudinary_url}
                  alt="obituary-image"
                  className="obituary-image"
                />
                <div>
                  <div id="obit-title">
                    {obituary.name}
                    <p id="obit-date">{`${formatDate(
                      obituary.bornDate
                    )} - ${formatDate(obituary.diedDate)}`}</p>
                  </div>
                  {showDropdown[obituary.cloudinary_url] && (
                    <div className="dropdown">
                      <p id="obit-description">{obituary.obituary}</p>
                      <div className="audio-container">
                        <button
                          className={`play-pause ${
                            obituary.audioPlaying ? "pause" : "play"
                          }`}
                          onClick={(event) => handleAudioToggle(event, obituary, obituary.polly_url)}
                        >
                          <span className="sr-only">
                            {obituary.audioPlaying ? "Pause" : "Play"}
                          </span>
                        </button>
                        <audio src={obituary.polly_url} />
                      </div>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div id="empty-holder">
            <div id="message">No Obituary Yet.</div>
          </div>
        )}
      </div>
    </div>
  );
}

export default ObitDisplay;
