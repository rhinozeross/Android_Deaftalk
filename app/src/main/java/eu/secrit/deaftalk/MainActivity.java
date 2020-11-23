package eu.secrit.deaftalk;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognizerIntent;
import android.speech.tts.TextToSpeech;
import android.speech.tts.TextToSpeech.OnInitListener;
import android.speech.tts.UtteranceProgressListener;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ListView;
import android.widget.RadioButton;
import android.widget.Spinner;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.Hashtable;
import java.util.List;
import java.util.Locale;

public class MainActivity extends Activity implements OnInitListener,
        View.OnClickListener, AdapterView.OnItemClickListener {

    //notwendig für Text-to Speech
    private static final int RQ_CHECK_TTS_DATA = 1;
    private static final String TAG =
            MainActivity.class.getSimpleName();

    private final Hashtable<String, Locale> supportedLanguages =
            new Hashtable<>();

    private TextToSpeech tts;
    private String last_utterance_id;

    //notwendig für Speech-toText
    private static final int RQ_VOICE_RECOGNITION = 1;

    //the needed Variables
    private Spinner spinner;
    public Button btnVorlesen;
    private Button bntDelMessage;
    private Button btnDelAllHistory;
    private ListView chatView;
    private RadioButton me;
    private RadioButton guest;
    private EditText etInput;
    private Button ibtnSend;
    private Button ibtnMic;

    private ArrayList<Eintrag> messageList;
    private ArrayAdapter<Eintrag> arrayAdapterMessageList;
    private String vorleseText = "";
    private boolean fromMeOrYou; //Who will write the next Message


    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // die Sprachsynthesekomponente wurde
        // noch nicht initialisiert
        tts = null;
        // prüfen, ob Sprachpakete vorhanden sind
        Intent intent = new Intent();
        intent.setAction(TextToSpeech.Engine.ACTION_CHECK_TTS_DATA);
        startActivityForResult(intent, RQ_CHECK_TTS_DATA);

        // Verfügbarkeit der Spracherkennung prüfen
        PackageManager pm = getPackageManager();
        List<ResolveInfo> activities =
                pm.queryIntentActivities(new Intent(
                        RecognizerIntent.ACTION_RECOGNIZE_SPEECH), 0);
        if (activities.size() == 0) {
            ibtnMic.setEnabled(false);
            ibtnMic.setText(getString(R.string.not_present));
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // ggf. Ressourcen freigeben
        if (tts != null) {
            tts.shutdown();
        }
    }

    @Override
    protected void onActivityResult(int requestCode,
                                    int resultCode,
                                    Intent data) {
        switch (resultCode) {
            case 1:
                startTTS(requestCode, resultCode, data);
                break;
            case -1:
                startSTT(requestCode, resultCode, data);
                break;
        }
    }

    private void startSTT(int rQC, int rSC, Intent data) {
        //Rückgabe für Voice Recognition
        if (rQC == RQ_VOICE_RECOGNITION
                && rSC == RESULT_OK) {
            ArrayList<String> matches = data
                    .getStringArrayListExtra(
                            RecognizerIntent.EXTRA_RESULTS);
            if (matches.size() > 0) {
                etInput.setText(matches.get(0));
            }
        }
        super.onActivityResult(rQC, rSC, data);
    }

    private void startTTS(int rQC, int rSC, Intent data) {
        super.onActivityResult(rQC, rSC, data);
        // Sind Sprachpakete vorhanden?
        if (rQC == RQ_CHECK_TTS_DATA) {
            if (rSC ==
                    TextToSpeech.Engine.CHECK_VOICE_DATA_PASS) {
                // Initialisierung der Sprachkomponente starten
                tts = new TextToSpeech(this, this);
            } else {
                // Installation der Sprachpakete vorbereiten
                Intent installIntent = new Intent();
                installIntent.setAction(
                        TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA);
                startActivity(installIntent);
                // Activity beenden
                finish();
            }
        }
    }

    @Override
    public void onInit(int status) {
        if (status != TextToSpeech.SUCCESS) {
            // die Initialisierung war nicht erfolgreich
            finish();
        }
        // Activity initialisieren
        setContentView(R.layout.activity_main);

        //GUI Elemente
        spinner = findViewById(R.id.locale);
        btnVorlesen = findViewById(R.id.btnVorlesen);
        btnVorlesen.setOnClickListener(this);
        bntDelMessage = findViewById(R.id.btnDelMessage);
        bntDelMessage.setOnClickListener(this);
        btnDelAllHistory = findViewById(R.id.btnDelAllHistory);
        btnDelAllHistory.setOnClickListener(this);
        messageList = new ArrayList<Eintrag>();
        chatView = findViewById(R.id.Chatview);
        fromMeOrYou = true;
        me = findViewById(R.id.rBtnME);
        guest = findViewById(R.id.rBtnGUEST);
        etInput = findViewById(R.id.editTextInput);
        ibtnSend = findViewById(R.id.ibtnSend);
        ibtnSend.setOnClickListener(this);
        ibtnMic = findViewById(R.id.ibtnMic);
        ibtnMic.setOnClickListener(this);

        arrayAdapterMessageList = new ArrayAdapter<Eintrag>(
                this,
                android.R.layout.simple_list_item_1,
                android.R.id.text1,
                messageList
        );
        chatView.setAdapter(arrayAdapterMessageList);
        chatView.setOnItemClickListener(this);

        arrayAdapterMessageList.notifyDataSetChanged();

        //Text-to-Speech Komponenten prüfen
        tts.setOnUtteranceProgressListener(
                new UtteranceProgressListener() {

                    @Override
                    public void onStart(String utteranceId) {
                        Log.d(TAG, "onStart(): " + utteranceId);
                    }

                    @Override
                    public void onDone(final String utteranceId) {
                        final Handler h =
                                new Handler(Looper.getMainLooper());
                        h.post(() -> {
                            if (utteranceId.equals(last_utterance_id)) {
                                btnVorlesen.setEnabled(true);
                            }
                        });
                    }

                    @Override
                    public void onError(String utteranceId) {
                        Log.d(TAG, "onError(): " + utteranceId);
                    }

                });

        // Liste der Sprachen ermitteln
        String[] languages = Locale.getISOLanguages();
        for (String lang : languages) {
            Locale loc = new Locale(lang);
            switch (tts.isLanguageAvailable(loc)) {
                case TextToSpeech.LANG_MISSING_DATA:
                case TextToSpeech.LANG_NOT_SUPPORTED:
                    break;
                default:
                    String key = loc.getDisplayLanguage();
                    if (!supportedLanguages.containsKey(key)) {
                        supportedLanguages.put(key, loc);
                    }
                    break;
            }
        }

        ArrayAdapter<Object> adapter = new ArrayAdapter<>(this,
                android.R.layout.simple_spinner_item, supportedLanguages
                .keySet().toArray());

        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinner.setAdapter(adapter);
        spinner.setSelection(3);
        Load();
    }

    @Override
    protected  void onStop(){
        super.onStop();
        Save();
    }

    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.ibtnSend:
                onSendClick();
                break;
            case R.id.ibtnMic:
                onMicClick();
                break;
            case R.id.btnVorlesen:
                onVorlesenClick();
                break;
            case R.id.btnDelMessage:
                onDelMessageClick();
                break;
            case R.id.btnDelAllHistory:
                onDelAllClick();
                break;
        }
    }

    private void onDelMessageClick() {
        for (int i = 0; i < messageList.size(); i++) {
            if (messageList.get(i).isMarkiert()){
                messageList.remove(i);
            }
        }
        arrayAdapterMessageList.notifyDataSetChanged(); //update Arraylist
    }

    private void onDelAllClick() {
        messageList.clear();
        arrayAdapterMessageList.notifyDataSetChanged(); //update Arraylist
    }

    private void onSendClick() {
        Eintrag message = new Eintrag();
        message.setEintrag(etInput.getText().toString());
        message.setFromMeOrYou(fromMeOrYou);
        message.setMarkiert(false);

        if (!message.getEintrag().isEmpty()) {
            messageList.add(message); //add Text to List
            arrayAdapterMessageList.notifyDataSetChanged(); //update Arraylist
            etInput.getText().clear();
        }
    }

    private void onMicClick() {
        startVoiceRecognitionActivity();
    }

    private void onVorlesenClick() {

        if (vorleseText.isEmpty()) {
            vorleseText = "Bitte treffen Sie eine Auswahl";
        }
        String key = (String) spinner.getSelectedItem();
        Locale loc = supportedLanguages.get(key);
        if (loc != null) {
            btnVorlesen.setEnabled(false);
            tts.setLanguage(loc);
            last_utterance_id = Long.toString(System
                    .currentTimeMillis());
            tts.speak(vorleseText, TextToSpeech.QUEUE_FLUSH,
                    null, last_utterance_id);
            // in Datei schreiben
            File file = new File(getExternalFilesDir(
                    Environment.DIRECTORY_PODCASTS),
                    last_utterance_id
                            + ".wav");
            tts.synthesizeToFile(vorleseText, null, file,
                    last_utterance_id);
            Log.d(TAG, file.getAbsolutePath());
        }
    }

    public void rBtnMe_onClick(View view) {
        fromMeOrYou = true;
        guest.setChecked(false);
    }

    public void rBtnGuest_onClick(View view) {
        fromMeOrYou = false;
        me.setChecked(false);
    }

    @Override
    public void onItemClick(AdapterView<?> adapterView, View view, int position, long l) {
        //Adapterview<?> parent     -> Das Elternelement des angeklickten Listitems (in der Listview)
        //View view                 -> Das Listitem, das angeklickt wurde
        //int position              -> Die Position des Listitems in der Liste
        //long id                   -> die ID der angeklickten Zeile
        //pos = position;

        //Gehe die Messageliste durch und beim ausgewählten Element setze markiert auf "True"
        // und nehme den Eitrag und schreibe es in die variable
        for (int i = 0; i < messageList.size(); i++) {
            if (i == position) {
                messageList.get(i).setMarkiert(true);
                vorleseText = messageList.get(i).getEintrag();
            } else {
                messageList.get(i).setMarkiert(false);
            }
            arrayAdapterMessageList.notifyDataSetChanged();
        }
    }

    private void startVoiceRecognitionActivity() {
        Intent intent = new Intent(
                RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT,
                getString(R.string.prompt));
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "de-DE");
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        startActivityForResult(intent, RQ_VOICE_RECOGNITION);
    }

    private void Save() {

        //getExternalFilesDir(null) -> gibt den Pfad zum Speicherort der App im externen Speicher an
        //"eintraege.txt"           -> der Dateiname, unter dem wir die Datei speichern
        File objFile = new File(getExternalFilesDir(null), "history.txt");

        try {

            FileOutputStream fos = new FileOutputStream(objFile);//Schreibt eine Bytefolge in die Datei
            OutputStreamWriter osw = new OutputStreamWriter(fos);//Wandelt String in Bytefolge um

            //foreach -> iteriert über eine Collection oder ein Array
            for (Eintrag objEintrag : messageList){

                //Beispiel: "Ich"; "Text"; False;
                String data = objEintrag.isFromMeOrYou() +  ";" +  objEintrag.getEintrag() + ";" +  false + ";" + "\n";
                osw.write(data);
            }

            //GOLDENE REGEL: JEDER DATENSTROM muss IMMER geschlossen werden!!!
            osw.close();
            fos.close();

        } catch ( Exception ex){
            //Wenn ein Ausnahmefehler im Try-Block auftritt, macht das Programm hier weiter statt abzustürzen
            Log.e("App_Deaftalk", "save()", ex);
        }
    }

    private void Load(){
        File objFile = new File(getExternalFilesDir(null), "history.txt");

        try (FileReader fr =new FileReader(objFile);
             BufferedReader br = new BufferedReader(fr)) {

            String s;
            //Da wir neue Daten laden, sollten wir sicherstellen, dass die Liste leer ist, damit wir keine dubletten bekommen
            messageList.clear();

            //Lese die Datei ZEILENWEISE aus, solange der Zeilenwert nicht leer ist
            while ((s = br.readLine()) != null){

                //Die ausgelesene Zeile am ; aufsplitten
                String[] split = s.split(";");
                //neues Eintrag Objekt erstellen
                Eintrag objEintrag = new Eintrag();
                //Die ausgelesenen Werte zuweisen
                objEintrag.setFromMeOrYou(Boolean.parseBoolean(split[0]));
                objEintrag.setEintrag(split[1]);
                objEintrag.setMarkiert(Boolean.parseBoolean(split[2]));
                //das neue Objekt der Liste hinzufügen
                messageList.add(objEintrag);
            }

        } catch (Exception ex){
            Log.e("App_Deaftalk", "load()", ex);
        }
    }
}