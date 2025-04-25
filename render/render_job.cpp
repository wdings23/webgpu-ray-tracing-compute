#include <render/render_job.h>
#include <rapidjson/document.h>
#include <loader/loader.h>
#include <utils/LogPrint.h>

#include <sstream>

namespace Render
{
    /*
    **
    */
    void CRenderJob::createWithOnlyOutputAttachments(CreateInfo& createInfo)
    {
        mName = createInfo.mName;
        mType = createInfo.mJobType;
        mPassType = createInfo.mPassType;

#if defined(__EMSCRIPTEN__)
        char* acFileContent = nullptr;
        Loader::loadFile(
            &acFileContent,
            createInfo.mPipelineFilePath,
            true
        );
#else 
        std::vector<char> acFileContent;
        Loader::loadFile(
            acFileContent,
            createInfo.mPipelineFilePath,
            true
        );
#endif // __EMSCRIPTEN__

        rapidjson::Document doc;
        {
#if defined(__EMSCRIPTEN__)
            doc.Parse(acFileContent);
            Loader::loadFileFree(acFileContent);

            printf("parse json \"%s\"\n", createInfo.mPipelineFilePath.c_str());
#else
            doc.Parse(acFileContent.data());
#endif // __EMSCRIPTEN__
        }

        std::vector< wgpu::ColorTargetState> aTargetStates;
        uint32_t iNumOutputAttachments = 0;
        auto const& attachments = doc["Attachments"].GetArray();
        for(auto const& attachment : attachments)
        {
            std::string attachmentName = attachment["Name"].GetString();
            std::string attachmentType = attachment["Type"].GetString();
            
            std::vector<wgpu::TextureFormat> aViewFormats;
            wgpu::ColorTargetState colorTargetState = {};
            if(attachmentType == "TextureOutput")
            {
                std::string attachmentFormat = attachment["Format"].GetString();

                wgpu::TextureFormat format = wgpu::TextureFormat::RGBA32Float;
                if(attachmentFormat == "rgba16float")
                {
                    format = wgpu::TextureFormat::RGBA16Float;
                }
                else if(attachmentFormat == "rg16float")
                {
                    format = wgpu::TextureFormat::RG16Float;
                }
                else if(attachmentFormat == "r32float")
                {
                    format = wgpu::TextureFormat::R32Float;
                }
                aViewFormats.push_back(format);

                float fScaleX = 1.0f, fScaleY = 1.0f;
                if(attachment.HasMember("ScaleWidth"))
                {
                    fScaleX = attachment["ScaleWidth"].GetFloat();
                }

                if(attachment.HasMember("ScaleHeight"))
                {
                    fScaleY = attachment["ScaleHeight"].GetFloat();
                }

                // create texture
                wgpu::TextureDescriptor textureDescriptor = {};
                textureDescriptor.format = format;
                textureDescriptor.label = attachmentName.c_str();
                textureDescriptor.dimension = wgpu::TextureDimension::e2D;
                textureDescriptor.size.width = uint32_t((float)createInfo.miScreenWidth * fScaleX);
                textureDescriptor.size.height = uint32_t((float)createInfo.miScreenHeight * fScaleY);
                textureDescriptor.size.depthOrArrayLayers = 1;
                textureDescriptor.mipLevelCount = 1;
                textureDescriptor.sampleCount = 1;
                textureDescriptor.viewFormats = aViewFormats.data();
                textureDescriptor.usage = wgpu::TextureUsage::RenderAttachment | 
                    wgpu::TextureUsage::TextureBinding | 
                    wgpu::TextureUsage::CopySrc |
                    wgpu::TextureUsage::StorageBinding;
                textureDescriptor.viewFormatCount = 1;

                if(mType == Render::JobType::Copy)
                {
                    textureDescriptor.usage |= wgpu::TextureUsage::CopyDst;
                }

                mOutputImageAttachments[attachmentName] = createInfo.mpDevice->CreateTexture(&textureDescriptor);

                mOutputImageAttachments[attachmentName].SetLabel(std::string(mName + "-" + attachmentName).c_str());

                // save format
                wgpu::ColorTargetState targetState = {};
                targetState.format = format;
                aTargetStates.push_back(targetState);
                mOutputImageFormats.push_back(format);

                // create texture vuew and color attachment info
                wgpu::Texture& texture = mOutputImageAttachments[attachmentName];
                wgpu::RenderPassColorAttachment colorAttachment = {};
                colorAttachment.clearValue = {0.0f, 0.0f, 0.3f, 0.0f};
                wgpu::TextureViewDescriptor viewDesc = {};
                viewDesc.format = mOutputImageFormats.back();
                viewDesc.dimension = wgpu::TextureViewDimension::e2D;
                viewDesc.mipLevelCount = 1;
                viewDesc.arrayLayerCount = 1;
                colorAttachment.view = texture.CreateView(&viewDesc);
                colorAttachment.loadOp = mLoadOp;
                colorAttachment.storeOp = mStoreOp;
                maOutputAttachments.push_back(colorAttachment);

                mAttachmentOrder.push_back(std::make_pair(attachmentName, std::make_pair(attachmentType, attachmentFormat)));
            }
            else if(attachmentType == "BufferOutput")
            {
                std::string usage = "";
                uint32_t iSize = attachment["Size"].GetUint();
                if(attachment.HasMember("Usage"))
                {
                    usage = attachment["Usage"].GetString();
                }

                wgpu::BufferDescriptor bufferDesc = {};
                bufferDesc.size = iSize;
                bufferDesc.usage = wgpu::BufferUsage::Storage | wgpu::BufferUsage::CopyDst;
                if(usage == "Indirect")
                {
                    bufferDesc.usage |= wgpu::BufferUsage::Indirect;
                }

                mOutputBufferAttachments[attachmentName] = createInfo.mpDevice->CreateBuffer(&bufferDesc);
                mAttachmentOrder.push_back(std::make_pair(attachmentName, std::make_pair(attachmentType, "r32float")));
                mOutputBufferAttachments[attachmentName].SetLabel(attachmentName.c_str());
            }
            else if(attachmentType == "TextureInput")
            {
                mAttachmentOrder.push_back(std::make_pair(attachmentName, std::make_pair(attachmentType, "parentFormat")));
            }
            else if(attachmentType == "BufferInput")
            {
                mAttachmentOrder.push_back(std::make_pair(attachmentName, std::make_pair(attachmentType, "parentFormat")));
            }
        }

        if(mType == Render::JobType::Copy)
        {
            return;
        }

        if(doc.HasMember("ShaderResources"))
        {
            auto const& aShaderResources = doc["ShaderResources"].GetArray();
            for(auto const& shaderResource : aShaderResources)
            {
                std::map<std::string, std::string> uniformInfo;
                uniformInfo["name"] = shaderResource["name"].GetString();
                uniformInfo["type"] = shaderResource["type"].GetString();
                uniformInfo["usage"] = shaderResource["usage"].GetString();
                uniformInfo["sample"] = "float";
                if(shaderResource.HasMember("sample"))
                {
                    uniformInfo["sample"] = shaderResource["sample"].GetString();
                }

                if(uniformInfo["type"] == "buffer")
                {
                    uint32_t iSize = 0;
                    if(shaderResource.HasMember("size") || shaderResource.HasMember("external") == false)
                    {
                        iSize = shaderResource["size"].GetUint();

                        std::string shaderStage = shaderResource["shader_stage"].GetString();

                        wgpu::BufferDescriptor bufferDesc = {};
                        bufferDesc.label = uniformInfo["name"].c_str();
                        bufferDesc.size = iSize;
                        if(uniformInfo["usage"] == "read_only_storage")
                        {
                            bufferDesc.usage = wgpu::BufferUsage::Storage | wgpu::BufferUsage::CopyDst;
                        }
                        else if(uniformInfo["usage"] == "uniform")
                        {
                            bufferDesc.usage = wgpu::BufferUsage::Uniform | wgpu::BufferUsage::CopyDst;
                        }
                        else if(uniformInfo["usage"] == "read_write_storage")
                        {
                            bufferDesc.usage = wgpu::BufferUsage::Storage | wgpu::BufferUsage::CopyDst | wgpu::BufferUsage::CopySrc;
                        }
                        else if(uniformInfo["usage"] == "write_only_storage")
                        {
                            bufferDesc.usage = wgpu::BufferUsage::Storage | wgpu::BufferUsage::CopyDst | wgpu::BufferUsage::CopySrc;
                        }

                        mUniformBuffers[uniformInfo["name"]] = createInfo.mpDevice->CreateBuffer(&bufferDesc);
                    }
                    else
                    {
                        uint32_t iBufferSize = 0;
                        mUniformBuffers[uniformInfo["name"]] = createInfo.mpfnGetBuffer(iBufferSize, uniformInfo["name"], createInfo.mpUserData);
                    }
                }
                else if(uniformInfo["type"] == "texture")
                {
                    std::string shaderStage = shaderResource["shader_stage"].GetString();
                    bool bExternalTexture = false;
                    if(shaderResource.HasMember("external"))
                    {
                        mUniformTextures[uniformInfo["name"]] = createInfo.mpfnGetTexture(uniformInfo["name"], createInfo.mpUserData);
                    }
                }

                mUniformOrder.push_back(uniformInfo);

            }   // for shader
        }

        if(doc.HasMember("DepthStencilState"))
        {
            bool bDepthEnable = (std::string(doc["DepthStencilState"]["DepthEnable"].GetString()) == "True");
            std::string depthWriteMask = doc["DepthStencilState"]["DepthWriteMask"].GetString();
            std::string depthFunc = doc["DepthStencilState"]["DepthFunc"].GetString();
            bool bStencil = (std::string(doc["DepthStencilState"]["StencilEnable"].GetString()) == "True");

            mDepthStencilState.depthWriteEnabled = (depthWriteMask == "One");
            
            mDepthStencilState.depthCompare = wgpu::CompareFunction::Always;
            if(depthFunc == "LessEqual")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::LessEqual;
            }
            else if(depthFunc == "Never")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::Never;
            }
            else if(depthFunc == "Less")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::Less;
            }
            else if(depthFunc == "Equal")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::Equal;
            }
            else if(depthFunc == "LessEqual")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::LessEqual;
            }
            else if(depthFunc == "Greater")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::Greater;
            }
            else if(depthFunc == "NotEqual")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::NotEqual;
            }
            else if(depthFunc == "GreaterEqual")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::GreaterEqual;
            }
            else if(depthFunc == "Always")
            {
                mDepthStencilState.depthCompare = wgpu::CompareFunction::Always;
            }

            mDepthStencilState.depthBias = 0;
            mDepthStencilState.depthBiasSlopeScale = 0.0;
            mDepthStencilState.depthBiasClamp = 1.0f;

        }
        
        mFrontFace = wgpu::FrontFace::CCW;
        if(doc.HasMember("RasterState"))
        {
            std::string cullMode = doc["RasterState"]["CullMode"].GetString();
            std::string frontFace = doc["RasterState"]["FrontFace"].GetString();

            if(cullMode == "None")
            {
                mCullMode = wgpu::CullMode::None;
            }
            else if(cullMode == "Back")
            {
                mCullMode = wgpu::CullMode::Back;
            }
            else if(cullMode == "Front")
            {
                mCullMode = wgpu::CullMode::Front;
            }

            if(frontFace == "CounterClockwise")
            {
                mFrontFace = wgpu::FrontFace::CCW;
            }
            else if(frontFace == "Clockwise")
            {
                mFrontFace = wgpu::FrontFace::CW;
            }

            if(doc["RasterState"].HasMember("LoadOp"))
            {
                std::string loadOp = doc["RasterState"]["LoadOp"].GetString();
                if(loadOp == "Load")
                {
                    mLoadOp = wgpu::LoadOp::Load;
                }
            }

            if(doc["RasterState"].HasMember("StoreOp"))
            {
                std::string storeOp = doc["RasterState"]["StoreOp"].GetString();
                if(storeOp == "Discard")
                {
                    mStoreOp = wgpu::StoreOp::Discard;
                }
            }
        }
    }

    /*
    **
    */
    void CRenderJob::setCopyAttachments(CreateInfo& createInfo)
    {
#if defined(__EMSCRIPTEN__)
        char* acFileContent = nullptr;
        Loader::loadFile(
            &acFileContent,
            createInfo.mPipelineFilePath,
            true
        );
#else 
        std::vector<char> acFileContent;
        Loader::loadFile(
            acFileContent,
            createInfo.mPipelineFilePath,
            true
        );
#endif // __EMSCRIPTEN__

        rapidjson::Document doc;
        {
#if defined(__EMSCRIPTEN__)
            doc.Parse(acFileContent);
            Loader::loadFileFree(acFileContent);

            printf("parse json \"%s\"\n", createInfo.mPipelineFilePath.c_str());
#else
            doc.Parse(acFileContent.data());
#endif // __EMSCRIPTEN__
        }

        std::vector<Render::CRenderJob*>& apRenderJobs = *(createInfo.mpaRenderJobs);

        auto const& attachments = doc["Attachments"].GetArray();
        for(auto const& attachment : attachments)
        {
            std::string attachmentName = attachment["Name"].GetString();
            std::string attachmentType = attachment["Type"].GetString();

            if(attachmentType == "TextureOutput")
            {
                std::string parentJobName = attachment["ParentJobName"].GetString();
                std::string parentName = attachment["ParentName"].GetString();

                // get parent render job
                auto iter = std::find_if(
                    apRenderJobs.begin(),
                    apRenderJobs.end(),
                    [&](Render::CRenderJob* pRenderJob)
                    {
                        return pRenderJob->mName == parentJobName;
                    });
                assert(iter != apRenderJobs.end());

                // get image input attachment from parent output attachment
                Render::CRenderJob* pParentRenderJob = *iter;
                assert(pParentRenderJob->mOutputImageAttachments.find(parentName) != pParentRenderJob->mOutputImageAttachments.end());
                auto parentOutputAttachment = pParentRenderJob->mOutputImageAttachments.find(parentName);
                mInputImageAttachments[attachmentName] = &parentOutputAttachment->second;
            }
        }
    }

    /*
    **
    */
    void CRenderJob::createWithInputAttachmentsAndPipeline(CreateInfo& createInfo)
    {
        mName = createInfo.mName;
        mType = createInfo.mJobType;
        mPassType = createInfo.mPassType;

#if defined(__EMSCRIPTEN__)
        char* acFileContent = nullptr;
        Loader::loadFile(
            &acFileContent,
            createInfo.mPipelineFilePath,
            true
        );
#else 
        std::vector<char> acFileContent;
        Loader::loadFile(
            acFileContent,
            createInfo.mPipelineFilePath,
            true
        );
#endif // __EMSCRIPTEN__

        rapidjson::Document doc;
        {
#if defined(__EMSCRIPTEN__)
            doc.Parse(acFileContent);
            Loader::loadFileFree(acFileContent);

            printf("%s : %d parse json \"%s\"\n", 
                __FILE__,
                __LINE__,
                createInfo.mPipelineFilePath.c_str());
#else 
            doc.Parse(acFileContent.data());
#endif // __EMSCRIPTEN__
        }

        // shader code
        wgpu::ShaderModuleWGSLDescriptor wgslDesc = {};
        std::string shaderPath = std::string("shaders/") + doc["Shader"].GetString();
#if defined(__EMSCRIPTEN__)
        if(doc.HasMember("Emscripten Shader"))
        {
            shaderPath = std::string("shaders/") + doc["Emscripten Shader"].GetString();
            printf("!!! USE EMSCRIPTEN SHADER !!!\n");
        }

        char* acShaderFileContent = nullptr;
        Loader::loadFile(
            &acShaderFileContent,
            shaderPath,
            true
        );
        wgslDesc.code = acShaderFileContent;

        //printf("shader content: %s\n", acShaderFileContent);

#else 
        std::vector<char> acShaderFileContent;
        Loader::loadFile(
            acShaderFileContent,
            shaderPath,
            true
        );
        wgslDesc.code = acShaderFileContent.data();
#endif // __EMSCRIPTEN__

        wgpu::ShaderModuleDescriptor shaderModuleDescriptor
        {
            .nextInChain = &wgslDesc
        };
        wgpu::ShaderModule shaderModule = createInfo.mpDevice->CreateShaderModule(&shaderModuleDescriptor);
        shaderModule.SetLabel(std::string(mName + " Shader Module").c_str());

#if defined(__EMSCRIPTEN__)
        Loader::loadFileFree(acShaderFileContent);
#endif // __EMSCRIPTEN__

        // fill out input attachments 
        std::vector< wgpu::ColorTargetState> aTargetStates;
        uint32_t iNumOutputAttachments = 0;
        auto const& attachments = doc["Attachments"].GetArray();
        for(auto const& attachment : attachments)
        {
            std::string attachmentType = attachment["Type"].GetString();
            
            if(mType == Render::JobType::Graphics)
            {
                std::string attachmentFormat = ""; 
                if(attachment.HasMember("Format"))
                {
                    attachmentFormat = attachment["Format"].GetString();
                }

                wgpu::TextureFormat format = wgpu::TextureFormat::RGBA32Float;
                if(attachmentFormat == "rgba16float")
                {
                    format = wgpu::TextureFormat::RGBA16Float;
                }
                else if(attachmentFormat == "rg16float")
                {
                    format = wgpu::TextureFormat::RG16Float;
                }

                std::vector<wgpu::TextureFormat> aViewFormats;
                aViewFormats.push_back(format);
            }

            std::vector<CRenderJob*>& aRenderJobs = *createInfo.mpaRenderJobs;

            // parent render job output attachment to this render job input attachment
            wgpu::ColorTargetState colorTargetState = {};
            if(attachmentType == "TextureInput" || attachmentType == "TextureInputOutput")
            {
                std::string attachmentName = attachment["Name"].GetString();
                std::string parentAttachmentName = attachmentName;
                if(attachment.HasMember("ParentName"))
                {
                    parentAttachmentName = attachment["ParentName"].GetString();
                }

                std::string attachmentParentJobName = attachment["ParentJobName"].GetString();

                bool bFound = false;
                for(auto const& renderJob : aRenderJobs)
                {
                    if(attachmentParentJobName == renderJob->mName)
                    {
                        bFound = true;
                        if(renderJob->mOutputImageAttachments.find(parentAttachmentName) != renderJob->mOutputImageAttachments.end())
                        {
                            if(attachmentName == "Depth Output" && mPassType == PassType::DrawMeshes)
                            {
                                mDepthStencilTexture = renderJob->mDepthStencilTexture;
                                mDepthStencilAttachment = renderJob->mDepthStencilAttachment;
                            }
                            else
                            {
                                mInputImageAttachments[attachmentName] = &renderJob->mOutputImageAttachments[parentAttachmentName];
                            }

                            break;
                        }
                        else
                        {
                            assert(!"Can\'t find input attachment");
                        }
                    }
                
                }   // for render job in all render jobs

                if(attachmentParentJobName == "Draw Text Graphics")
                {
                    mInputImageAttachments[attachmentName] = createInfo.mpDrawTextOutputAttachment;
                    bFound = true;
                }

                assert(bFound);

            }   // if attachment type == Texture input
            if(attachmentType == "BufferInput" || attachmentType == "BufferInputOutput")
            {
                std::string attachmentName = attachment["Name"].GetString();
                std::string parentAttachmentName = attachmentName;
                if(attachment.HasMember("ParentName"))
                {
                    parentAttachmentName = attachment["ParentName"].GetString();
                }

                std::string attachmentParentJobName = attachment["ParentJobName"].GetString();

                bool bFound = false;
                for(auto const& renderJob : aRenderJobs)
                {
                    if(attachmentParentJobName == renderJob->mName)
                    {
                        bFound = true;
                        if(renderJob->mOutputBufferAttachments.find(parentAttachmentName) != renderJob->mOutputBufferAttachments.end())
                        {
                            mInputBufferAttachments[attachmentName] = &renderJob->mOutputBufferAttachments[parentAttachmentName];
                            
                            break;
                        }
                        else
                        {
                            assert(!"Can\'t find input attachment");
                        }
                    }

                }   // for render job in all render jobs

                if(attachmentParentJobName == "Draw Text Graphics")
                {
                    mInputImageAttachments[attachmentName] = createInfo.mpDrawTextOutputAttachment;
                    bFound = true;
                }

                assert(bFound);

            }   // if attachment type == Texture input

        }   // for attachment in attachments

        wgpu::BlendState blendState = {};
        blendState.color.srcFactor = wgpu::BlendFactor::SrcAlpha;
        blendState.color.dstFactor = wgpu::BlendFactor::OneMinusSrcAlpha;
        blendState.color.operation = wgpu::BlendOperation::Add;
        blendState.alpha.srcFactor = wgpu::BlendFactor::Zero;
        blendState.alpha.dstFactor = wgpu::BlendFactor::One;
        blendState.alpha.operation = wgpu::BlendOperation::Add;

        // output attachment formats
        std::vector<wgpu::ColorTargetState> aColorTargetState;
        for(auto const& outputImageFormat : mOutputImageFormats)
        {
            wgpu::ColorTargetState colorTargetState = {};
            colorTargetState.format = outputImageFormat;
            colorTargetState.blend = nullptr; // disable blending for now
            aColorTargetState.push_back(colorTargetState);
        }

        // depth format
        if(mDepthStencilState.depthWriteEnabled)
        {
            wgpu::ColorTargetState colorTargetState = {};
            colorTargetState.format = wgpu::TextureFormat::Depth32Float;
            aColorTargetState.push_back(colorTargetState);
        }

        // fragment shader 
        // vertex format attributes
        wgpu::FragmentState fragmentState = {};
        wgpu::VertexState vertexState = {};
        wgpu::VertexBufferLayout vertexBufferLayout = {};
        std::vector<wgpu::VertexAttribute> aVertexAttributes;
        wgpu::VertexAttribute attrib = {};

        if(mType == Render::JobType::Graphics)
        {
            fragmentState.module = shaderModule;
            fragmentState.targetCount = (uint32_t)mOutputImageAttachments.size();
            fragmentState.targets = aColorTargetState.data();
            fragmentState.entryPoint = "fs_main";

            attrib.format = wgpu::VertexFormat::Float32x4;
            attrib.offset = 0;
            attrib.shaderLocation = 0;
            aVertexAttributes.push_back(attrib);
            attrib.offset = sizeof(float4);
            attrib.shaderLocation = 1;
            aVertexAttributes.push_back(attrib);
            attrib.offset = sizeof(float4) * 2;
            attrib.shaderLocation = 2;
            aVertexAttributes.push_back(attrib);

            // vertex layout
            vertexBufferLayout.attributeCount = 3;
            vertexBufferLayout.arrayStride = sizeof(float4) * 3;
            vertexBufferLayout.attributes = aVertexAttributes.data();
            vertexBufferLayout.stepMode = wgpu::VertexStepMode::Vertex;

            // vertex shader
            vertexState.module = shaderModule;
            vertexState.entryPoint = "vs_main";
            vertexState.buffers = &vertexBufferLayout;
            vertexState.bufferCount = 1;
        }
        else if(mType == Render::JobType::Compute)
        {

        }
        else
        {
            assert(!"no such job type");
        }

        // bind group layout
        std::vector<std::vector<wgpu::BindGroupLayoutEntry>> aaBindGroupLayoutEntries(2);
        uint32_t iIndex = 0;
        
        std::vector<std::vector<wgpu::BindGroupEntry>> aaBindingGroupEntries(2);

        DEBUG_PRINTF("Render Job: \"%s\"\n", mName.c_str());

        // in/out attachments in group 0
        for(auto const& attachmentInfo : mAttachmentOrder)
        {
            std::string const& attachmentName = attachmentInfo.first;
            std::string const& attachmentType = attachmentInfo.second.first;
            std::string const& attachmentFormat = attachmentInfo.second.second;

            if(mType == Render::JobType::Graphics)
            {
                if(attachmentType == "TextureOutput" || attachmentType == "TextureInputOutput")
                {
                    continue;
                }
            }

            wgpu::BindGroupEntry bindGroupEntry = {};
            wgpu::BindGroupLayoutEntry bindingLayout = {};
            bindingLayout.binding = iIndex;
            bindGroupEntry.binding = iIndex;
            if(attachmentType == "TextureInput")
            {
                bindingLayout.texture.multisampled = false;
                bindingLayout.texture.sampleType = wgpu::TextureSampleType::UnfilterableFloat;
                bindingLayout.texture.viewDimension = wgpu::TextureViewDimension::e2D;
                bindingLayout.visibility = wgpu::ShaderStage::Fragment;
                if(mType == Render::JobType::Compute)
                {
                    bindingLayout.visibility = wgpu::ShaderStage::Compute;
                }

                wgpu::TextureView textureView = mInputImageAttachments[attachmentName]->CreateView();
                bindGroupEntry.textureView = textureView;
                
                DEBUG_PRINTF("\tgroup 0 binding %d read texture \"%s\"\n",
                    (uint32_t)aaBindGroupLayoutEntries[0].size(),
                    attachmentName.c_str());
            }
            else if(attachmentType == "TextureOutput")
            {
                bindingLayout.texture.multisampled = false;
                bindingLayout.texture.sampleType = wgpu::TextureSampleType::UnfilterableFloat;
                bindingLayout.texture.viewDimension = wgpu::TextureViewDimension::e2D;

                wgpu::TextureView textureView = mOutputImageAttachments[attachmentName].CreateView();
                bindGroupEntry.textureView = textureView;

                DEBUG_PRINTF("\tgroup 0 binding %d write texture \"%s\"\n",
                    (uint32_t)aaBindGroupLayoutEntries[0].size(),
                    attachmentName.c_str());
            }
            else if(attachmentType == "BufferInput")
            {
                bindingLayout.buffer.type = wgpu::BufferBindingType::ReadOnlyStorage;
                bindingLayout.buffer.minBindingSize = 0;
                bindingLayout.visibility = wgpu::ShaderStage::Vertex | wgpu::ShaderStage::Fragment;
                if(mType == Render::JobType::Compute)
                {
                    bindingLayout.visibility = wgpu::ShaderStage::Compute;
                }
                bindGroupEntry.buffer = *mInputBufferAttachments[attachmentName];

                DEBUG_PRINTF("\tgroup 0 binding %d read buffer \"%s\"\n",
                    (uint32_t)aaBindGroupLayoutEntries[0].size(),
                    attachmentName.c_str());
            }
            else if(attachmentType == "BufferOutput")
            {
                bindingLayout.buffer.type = wgpu::BufferBindingType::Storage;
                bindingLayout.buffer.minBindingSize = 0;
                bindingLayout.visibility = wgpu::ShaderStage::Vertex | wgpu::ShaderStage::Fragment;
                if(mType == Render::JobType::Compute)
                {
                    bindingLayout.visibility = wgpu::ShaderStage::Compute;
                }

                bindGroupEntry.buffer = mOutputBufferAttachments[attachmentName];

                DEBUG_PRINTF("\tgroup 0 binding %d write buffer \"%s\"\n",
                    (uint32_t)aaBindGroupLayoutEntries[0].size(),
                    attachmentName.c_str());
            }
            
            ++iIndex;

            aaBindGroupLayoutEntries[0].push_back(bindingLayout);
            aaBindingGroupEntries[0].push_back(bindGroupEntry);
        }

        // shader resouces in group 1
        iIndex = 0;
        for(auto& uniformInfo : mUniformOrder)
        {
            std::string const& uniformName = uniformInfo["name"];
            std::string const& uniformType = uniformInfo["type"];
            std::string const& uniformUsage = uniformInfo["usage"];

            wgpu::BindGroupEntry bindGroupEntry = {};
            wgpu::BindGroupLayoutEntry bindingLayout = {};

            bindingLayout.binding = iIndex;
            bindGroupEntry.binding = iIndex;
            if(uniformType == "texture")
            {
                if(uniformUsage == "write_only_storage")
                {
                    bindingLayout.storageTexture.access = wgpu::StorageTextureAccess::WriteOnly;
                    bindingLayout.storageTexture.format = wgpu::TextureFormat::RGBA32Float;
                    bindingLayout.storageTexture.viewDimension = wgpu::TextureViewDimension::e2D;
                }
                else
                {
                    bindingLayout.texture.multisampled = false;
                    bindingLayout.texture.sampleType = wgpu::TextureSampleType::Float;
                    bindingLayout.texture.viewDimension = wgpu::TextureViewDimension::e2D;

                    if(uniformInfo["sample"] == "unfilterable_float")
                    {
                        bindingLayout.texture.sampleType = wgpu::TextureSampleType::UnfilterableFloat;
                    }
                }

                bindGroupEntry.textureView = mUniformTextures[uniformName].CreateView();
                
                DEBUG_PRINTF("\tgroup 1 binding %d texture \"%s\"\n",
                    (uint32_t)aaBindGroupLayoutEntries[1].size(),
                    uniformName.c_str());
            }
            else if(uniformType == "buffer")
            {
                bindingLayout.buffer.type = wgpu::BufferBindingType::ReadOnlyStorage;
                bindingLayout.buffer.minBindingSize = 0; // 64;
            
                if(uniformUsage == "read_write_storage")
                {
                    bindingLayout.buffer.type = wgpu::BufferBindingType::Storage;

                    DEBUG_PRINTF("\tgroup 1 binding %d write buffer \"%s\"\n",
                        (uint32_t)aaBindGroupLayoutEntries[1].size(),
                        uniformName.c_str());
                }
                else if(uniformUsage == "uniform")
                {
                    bindingLayout.buffer.type = wgpu::BufferBindingType::Uniform;

                    DEBUG_PRINTF("\tgroup 1 binding %d uniform buffer \"%s\"\n",
                        (uint32_t)aaBindGroupLayoutEntries[1].size(),
                        uniformName.c_str());
                }
                
                bindGroupEntry.buffer = mUniformBuffers[uniformName];
            }

            bindingLayout.visibility = wgpu::ShaderStage::Vertex | wgpu::ShaderStage::Fragment;
            if(mType == Render::JobType::Compute)
            {
                bindingLayout.visibility = wgpu::ShaderStage::Compute;
            }
            else
            {
                if(uniformUsage == "read_write_storage" || uniformUsage == "write_only_storage")
                {
                    bindingLayout.visibility = wgpu::ShaderStage::Fragment;
                }
            }
            

            aaBindGroupLayoutEntries[1].push_back(bindingLayout);
            aaBindingGroupEntries[1].push_back(bindGroupEntry);
            ++iIndex;
        }

        // add default uniform buffer at the end of set 1
        {
            wgpu::BindGroupEntry bindGroupEntry = {};
            wgpu::BindGroupLayoutEntry bindingLayout = {};

            bindGroupEntry.binding = iIndex;
            bindGroupEntry.buffer = *createInfo.mpDefaultUniformBuffer;
            
            bindingLayout.binding = iIndex;
            bindingLayout.buffer.type = wgpu::BufferBindingType::Uniform;
            bindingLayout.buffer.minBindingSize = createInfo.mpDefaultUniformBuffer->GetSize();
            bindingLayout.visibility = wgpu::ShaderStage::Vertex | wgpu::ShaderStage::Fragment;
            if(mType == Render::JobType::Compute)
            {
                bindingLayout.visibility = wgpu::ShaderStage::Compute;
            }

            aaBindGroupLayoutEntries[1].push_back(bindingLayout);
            aaBindingGroupEntries[1].push_back(bindGroupEntry);

            DEBUG_PRINTF("\tgroup 1 binding %d \"default uniform buffer\"\n",
                iIndex);

            ++iIndex;
        }

        // add sampler if there are textures
        if(mOutputImageAttachments.size() > 0 || mUniformTextures.size() > 0)
        {
            wgpu::BindGroupEntry bindGroupEntry = {};
            wgpu::BindGroupLayoutEntry bindingLayout = {};

            bindGroupEntry.binding = iIndex;
            bindGroupEntry.sampler = *createInfo.mpSampler;

            bindingLayout.binding = iIndex;
            bindingLayout.sampler.type = wgpu::SamplerBindingType::NonFiltering;
            bindingLayout.visibility = wgpu::ShaderStage::Fragment;

            aaBindGroupLayoutEntries[1].push_back(bindingLayout);
            aaBindingGroupEntries[1].push_back(bindGroupEntry);

            DEBUG_PRINTF("\tgroup 1 binding %d \"sampler\"\n",
                iIndex);

            ++iIndex;
        }

        // bind group layouts
        std::vector<wgpu::BindGroupLayout> aBindGroupLayout(2);
        for(uint32_t iGroup = 0; iGroup < 2; iGroup++)
        {
            wgpu::BindGroupLayoutDescriptor groupLayoutDesc = {};
            groupLayoutDesc.entryCount = (uint32_t)aaBindGroupLayoutEntries[iGroup].size();
            groupLayoutDesc.entries = aaBindGroupLayoutEntries[iGroup].data();
            aBindGroupLayout[iGroup] = createInfo.mpDevice->CreateBindGroupLayout(&groupLayoutDesc);
        
            std::ostringstream oss;
            oss << mName << " Bind Group Layout " << iGroup;
            aBindGroupLayout[iGroup].SetLabel(oss.str().c_str());
        }

        // bind group
        maBindGroups.resize(2);
        for(uint32_t iGroup = 0; iGroup < 2; iGroup++)
        {
            wgpu::BindGroupDescriptor groupDesc = {};
            groupDesc.layout = aBindGroupLayout[iGroup];
            groupDesc.entries = aaBindingGroupEntries[iGroup].data();
            groupDesc.entryCount = (uint32_t)aaBindingGroupEntries[iGroup].size();

            maBindGroups[iGroup] = createInfo.mpDevice->CreateBindGroup(&groupDesc);
            
            std::ostringstream oss;
            oss << mName << " Bind Group " << iGroup;
            maBindGroups[iGroup].SetLabel(oss.str().c_str());
        }

        // pipeline layout
        wgpu::PipelineLayoutDescriptor layoutDesc = {};
        layoutDesc.bindGroupLayoutCount = (uint32_t)aBindGroupLayout.size();
        layoutDesc.bindGroupLayouts = aBindGroupLayout.data();
        wgpu::PipelineLayout pipelineLayout = createInfo.mpDevice->CreatePipelineLayout(&layoutDesc);

        // pipeine descriptor
        std::string pipelineName = mName + " Pipeline";
        if(mType == JobType::Graphics)
        {
            wgpu::RenderPipelineDescriptor pipelineDescriptor = {};
            pipelineDescriptor.vertex = vertexState;
            pipelineDescriptor.fragment = &fragmentState;
            pipelineDescriptor.label = pipelineName.c_str();
            pipelineDescriptor.primitive.topology = wgpu::PrimitiveTopology::TriangleList;
            pipelineDescriptor.primitive.stripIndexFormat = wgpu::IndexFormat::Undefined;
            pipelineDescriptor.primitive.frontFace = mFrontFace;
            pipelineDescriptor.primitive.cullMode = mCullMode;
            pipelineDescriptor.depthStencil = &mDepthStencilState;
            pipelineDescriptor.layout = pipelineLayout;
            mDepthStencilState.format = wgpu::TextureFormat::Depth32Float;
            mRenderPipeline = createInfo.mpDevice->CreateRenderPipeline(&pipelineDescriptor);
            mRenderPipeline.SetLabel(pipelineDescriptor.label);

            // depth texture
            if(mDepthStencilTexture == nullptr)
            {
                mDepthStencilViewFormat = wgpu::TextureFormat::Depth32Float;
                wgpu::TextureDescriptor depthStencilDesc = {};
                depthStencilDesc.dimension = wgpu::TextureDimension::e2D;
                depthStencilDesc.usage = wgpu::TextureUsage::RenderAttachment | wgpu::TextureUsage::TextureBinding;
                depthStencilDesc.format = wgpu::TextureFormat::Depth32Float;
                depthStencilDesc.viewFormats = &mDepthStencilViewFormat;
                depthStencilDesc.size.width = mOutputImageAttachments.begin()->second.GetWidth();
                depthStencilDesc.size.height = mOutputImageAttachments.begin()->second.GetHeight();
                depthStencilDesc.size.depthOrArrayLayers = 1;
                mDepthStencilTexture = createInfo.mpDevice->CreateTexture(&depthStencilDesc);
                mOutputImageAttachments["Depth Output"] = mDepthStencilTexture;

                // depth texture view
                wgpu::TextureViewDescriptor depthStencilViewDesc = {};
                depthStencilViewDesc.format = wgpu::TextureFormat::Depth32Float;
                depthStencilViewDesc.mipLevelCount = 1;
                depthStencilViewDesc.arrayLayerCount = 1;
                depthStencilViewDesc.dimension = wgpu::TextureViewDimension::e2D;
                mDepthStencilAttachment.view = mDepthStencilTexture.CreateView(&depthStencilViewDesc);
                mDepthStencilAttachment.depthClearValue = 1.0f;
                mDepthStencilAttachment.depthStoreOp = mStoreOp;
                mDepthStencilAttachment.depthLoadOp = mLoadOp;
            }
            else
            {
                mDepthStencilAttachment.depthClearValue = 1.0f;
                mDepthStencilAttachment.depthStoreOp = wgpu::StoreOp::Store;
                mDepthStencilAttachment.depthLoadOp = wgpu::LoadOp::Load;
            }
            
            // render pass descriptor
            mRenderPassDesc.colorAttachmentCount = (uint32_t)maOutputAttachments.size();
            mRenderPassDesc.colorAttachments = maOutputAttachments.data();
            mRenderPassDesc.depthStencilAttachment = &mDepthStencilAttachment;

            printf("create pipeline: \"%s\"\n", pipelineName.c_str());
        }
        else if(mType == JobType::Compute)
        {
#if defined(__EMSCRIPTEN__)
            wgpu::ProgrammableStageDescriptor computeDesc = {};
            computeDesc.module = shaderModule;
            computeDesc.entryPoint = "cs_main";
            computeDesc.constants = nullptr;
            computeDesc.constantCount = 0;
#else 
            wgpu::ComputeState computeDesc = {};
            computeDesc.module = shaderModule;
            computeDesc.entryPoint = "cs_main";
            computeDesc.constants = nullptr;
            computeDesc.constantCount = 0;
#endif // __EMSCRIPTEN__

            wgpu::ComputePipelineDescriptor pipelineDescriptor = {};
            pipelineDescriptor.compute = computeDesc;
            pipelineDescriptor.layout = pipelineLayout;
            mComputePipeline = createInfo.mpDevice->CreateComputePipeline(&pipelineDescriptor);
            std::string pipelineName = mName + " Compute Pipeline";
            mComputePipeline.SetLabel(pipelineName.c_str());
            
            printf("create pipeline: \"%s\"\n", pipelineName.c_str());
        }
        else
        {
            assert(!"handle this job type");
        }
    }

}   // Render