/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useEffect, useRef, useState} from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
  NativeModules,
  NativeEventEmitter,
  Touchable,
  TouchableOpacity,
} from 'react-native';

import {
  Colors,
  DebugInstructions,
  Header,
  LearnMoreLinks,
  ReloadInstructions,
} from 'react-native/Libraries/NewAppScreen';

const {MTLSWebSocketModule} = NativeModules;

function App() {
  const [errorMessages, setErrorMessages] = useState([]);

  const [messageFromServer, setMessageFromServer] = useState('');

  const isDarkMode = useColorScheme() === 'dark';
  const eventEmitter = new NativeEventEmitter(MTLSWebSocketModule);

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  // const connectWebSocket = () => {
  //   MTLSWebSocketModule.connect('wss://localhost:8083');
  // };

  // const ipAddress = '192.168.115:443';

  const ipAddress = '192.168.68.150:8083';

  const connectWebSocket = () => {
    MTLSWebSocketModule.connect(`wss://${ipAddress}/semictrl`);
  };

  const getServerStatus = () => {
    const cmd = JSON.stringify({CMD: 'GET-SEMI-STATUS'});
    MTLSWebSocketModule.send(cmd);
  };

  const getAllValsFromServer = () => {
    const cmd = JSON.stringify({CMD: 'IND-GET-VALS-PER'});
    MTLSWebSocketModule.send(cmd);
  };

  useEffect(() => {
    const onMessage = eventEmitter.addListener('onMessage', message => {
      console.log('Message received: ', message);
      // const parsedMessage = JSON.parse(message);
      setMessageFromServer(message);
    });

    const onError = eventEmitter.addListener('onError', error => {
      if (error) {
        setErrorMessages([...errorMessages, error]);
      }
    });

    const onConnectionOpen = eventEmitter.addListener(
      'onConnectionOpen',
      () => {
        setErrorMessages([...errorMessages, 'Connection open']);
      },
    );

    const onConnectionClosed = eventEmitter.addListener(
      'onConnectionClosed',
      () => {
        setErrorMessages([...errorMessages, 'Connection closed']);
      },
    );

    // Cleanup listeners when the component unmounts
    return () => {
      onMessage.remove();
      onError.remove();
      onConnectionOpen.remove();
      onConnectionClosed.remove();
    };
  }, []);

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
        <View
          style={{
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
          }}>
          <View style={styles.header}>
            <Text style={styles.sectionTitle}>
              MTLS WebSocket @ {ipAddress}
            </Text>
            <TouchableOpacity onPress={() => connectWebSocket()}>
              <Text>Connect WSS</Text>
            </TouchableOpacity>
          </View>
        </View>
        <View style={{padding: 20}}>
          <Text>Errors:</Text>
          {errorMessages.map((error, index) => (
            <Text key={index}>{error}</Text>
          ))}
          <TouchableOpacity
            onPress={() => setErrorMessages([])}
            style={{marginTop: 50}}>
            <Text>Clear </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
      <View style={{padding: 20}}>
        <TouchableOpacity
          onPress={() => getServerStatus()}
          style={{paddingBottom: 20}}>
          <Text>Get Server Status</Text>
        </TouchableOpacity>
        <Text>Message from server:</Text>
        <Text>{messageFromServer}</Text>
      </View>

      <View style={{padding: 20}}>
        <TouchableOpacity
          onPress={() => getAllValsFromServer()}
          style={{paddingBottom: 20}}>
          <Text>Get All Vals From Server</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
  },
  highlight: {
    fontWeight: '700',
  },
  header: {
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
});

export default App;
