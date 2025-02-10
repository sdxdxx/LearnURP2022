using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
 
namespace UnityEditor.Rendering.Universal
{
    
    enum ScreenSpaceReflectionType
    {
        Simple_ViewSpace = 1,
        BinarySearch_ViewSpace,
        Efficient_ScreenSpace
    }
    
    [CustomEditor(typeof(ScreenSpaceReflectionVolume))]
    sealed class ScreenSpaceReflectionVolumeComponentEditor : VolumeComponentEditor
    {
        private SerializedDataParameter m_ScreenSpaceReflectionMode;
        private SerializedDataParameter m_EnableReflection;
        private SerializedDataParameter m_ShowReflectionTexture;
        private SerializedDataParameter m_ColorChange;
        private SerializedDataParameter m_StepLength;
        private SerializedDataParameter m_Thickness;
        private SerializedDataParameter m_MaxStepLength;
        private SerializedDataParameter m_MinDistance;
        private SerializedDataParameter m_MaxReflectLength;
        
        public override void OnEnable()
        {
            var o = new PropertyFetcher<ScreenSpaceReflectionVolume>(serializedObject);

            m_ScreenSpaceReflectionMode = Unpack(o.Find(x => x.ScreenSpaceReflectionMode));
            m_EnableReflection = Unpack(o.Find(x => x.EnableReflection));
            m_ShowReflectionTexture = Unpack(o.Find(x => x.ShowReflectionTexture));
            m_ColorChange = Unpack(o.Find(x => x.ColorChange));
            m_StepLength = Unpack(o.Find(x => x.StepLength));
            m_Thickness = Unpack(o.Find(x => x.Thickness));
            m_MaxStepLength = Unpack(o.Find(x => x.MaxStepLength));
            m_MinDistance = Unpack(o.Find(x => x.MinDistance));
            m_MaxReflectLength = Unpack(o.Find(x => x.MaxReflectLength));
        }
        
        public override void OnInspectorGUI()
        {
            EditorGUILayout.LabelField("Screen Space Reflection Settings", EditorStyles.largeLabel);
            
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            var screenSpaceReflectionVolume = stack.GetComponent<ScreenSpaceReflectionVolume>();//从栈中获取到screenSpaceReflectionVolume 
            PropertyField(m_ScreenSpaceReflectionMode);
            PropertyField(m_EnableReflection);
            PropertyField(m_ShowReflectionTexture);
            PropertyField(m_ColorChange);

            switch ((ScreenSpaceReflectionType)screenSpaceReflectionVolume.ScreenSpaceReflectionMode.value)
            {
                case ScreenSpaceReflectionType.Simple_ViewSpace:
                {
                    PropertyField(m_StepLength);
                    PropertyField(m_Thickness);
                    break;
                }

                case ScreenSpaceReflectionType.BinarySearch_ViewSpace:
                {
                    PropertyField(m_MaxStepLength);
                    PropertyField(m_MinDistance);
                    break;
                }

                case ScreenSpaceReflectionType.Efficient_ScreenSpace:
                {
                    PropertyField(m_MaxReflectLength);
                    PropertyField(m_Thickness);
                    break;
                }
            }
        }
    }
}