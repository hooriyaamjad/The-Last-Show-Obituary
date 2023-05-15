import ObitDisplay from "./ObitDisplay";
import NewObituaryScreen from "./NewObituaryScreen";
import { useEffect, useState } from "react";


function App() {
  const [showNewObituaryScreen, setShowNewObituaryScreen] = useState(false);
  const [obituaries, setObituaries] = useState([]);

  return (
    <div id="container">
      {showNewObituaryScreen ? (
        <NewObituaryScreen 
        setObituaries={setObituaries}
        setShowNewObituaryScreen={setShowNewObituaryScreen}/>
      ) : (
        <ObitDisplay 
        obituaries={obituaries}
        setObituaries={setObituaries}
        setShowNewObituaryScreen={setShowNewObituaryScreen} />
      )}
    </div>
  );
}

export default App;
